class HerokuLogsAnalyzer

  # Math proof:
  # http://www.grandars.ru/student/statistika/strukturnye-srednie-velichiny.html
  # http://univer-nn.ru/statistika/moda-i-mediana/

  TIME_INTERVAL_SIZE = 20

  def initialize log_path
    raise ArgumentError unless File.exists?(log_path)

    @log_file = File.open(log_path)
  end

  def do_analyze
    # Requests:
    # GET /api/users/{user_id}/count_pending_messages
    # GET /api/users/{user_id}/get_messages
    # GET /api/users/{user_id}/get_friends_progress
    # GET /api/users/{user_id}/get_friends_score
    # POST /api/users/{user_id}
    # GET /api/users/{user_id}
    self.emit {|l| puts l}
    @log_file.close
  end

  def show_busiest_dynos dynos
    top_load = -1.0/0.0
    busiest_dynos = []
    dynos.each do |key, val|
      if val > top_load
        busiest_dynos = []
        top_load = val
      end
      busiest_dynos.push key if val == top_load
    end
    busiest_dynos
  end

  def find_mode times
    max_time = times.length

    i_start = 0
    i_end = TIME_INTERVAL_SIZE
    avg_times = Array.new
    while i_start < max_time do
      i = i_start
      avg_time = 0
      while i < i_end do
        avg_time += i*times[i].to_i
        i += 1
      end
      avg_time /= TIME_INTERVAL_SIZE
      avg_times << avg_time

      i_start += TIME_INTERVAL_SIZE
      i_end += TIME_INTERVAL_SIZE
    end

    index_of_max = avg_times.each_with_index.max[1]
    x0 = index_of_max * TIME_INTERVAL_SIZE
    h = TIME_INTERVAL_SIZE
    f = avg_times.max
    f_prev = avg_times[index_of_max - 1]
    f_next = avg_times[index_of_max + 1]
    moda = x0 + h*(f - f_prev)/((f - f_prev) + (f - f_next))
  end

  def find_mean_time request_times, cnt_lines
    mean_time = request_times.inject{|sum, x| sum + x } / cnt_lines
  end

  def find_median mean_time, mode
    # median formula
    # me = 0.5*mode + 2*mean_time/3
    median = 0.5*mode + 2*mean_time/3
  end

  def count_dynos dynos, dyno
    #dyno=web.8
    unless dynos[dyno.to_sym].nil?
      dynos[dyno.to_sym] += 1
    else
      dynos[dyno.to_sym] = 1
    end
    dynos
  end

  def count_time times, total_time
    unless times[total_time].nil?
      times[total_time] += 1
    else
      times[total_time] = 1
    end
    times
  end

  def emit &block
    cnt_get_count_pending_messages = 0
    cnt_get_messages = 0
    cnt_get_friends_progress = 0
    cnt_get_friends_score = 0
    cnt_post_user = 0
    cnt_get_user = 0
    cnt_lines = 0

    request_times = Array.new

    dynos = Array.new #Hash.new
    times = Array.new

    @log_file.each_line do |line|
      cnt_lines += 1
      #yield line

      connect_time = line.match(/connect=[0-9]*ms/).to_s.split("=").last.split("ms").first
      service_time = line.match(/service=[0-9]*ms/).to_s.split("=").last.split("ms").first
      total_time = connect_time.to_i + service_time.to_i

      dyno = line.match(/dyno=web.[0-9]*/).to_s.split("=").last

      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/count_pending_messages/)
        cnt_get_count_pending_messages += 1

        dynos[0] ||= Hash.new
        dynos[0] = count_dynos dynos[0], dyno

        request_times[0] ||= Array.new
        request_times[0] << total_time

        times[0] ||= Array.new
        times[0] = count_time times[0], total_time
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/get_messages/)
        cnt_get_messages += 1

        dynos[1] ||= Hash.new
        dynos[1] = count_dynos dynos[1], dyno

        request_times[1] ||= Array.new
        request_times[1] << total_time

        times[1] ||= Array.new
        times[1] = count_time times[1], total_time
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/get_friends_progress/)
        cnt_get_friends_progress += 1

        dynos[2] ||= Hash.new
        dynos[2] = count_dynos dynos[2], dyno

        request_times[2] ||= Array.new
        request_times[2] << total_time

        times[2] ||= Array.new
        times[2] = count_time times[2], total_time
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/get_friends_score/)
        cnt_get_friends_score += 1

        dynos[3] ||= Hash.new
        dynos[3] = count_dynos dynos[3], dyno

        request_times[3] ||= Array.new
        request_times[3] << total_time

        times[3] ||= Array.new
        times[3] = count_time times[3], total_time
      end
      if line.match(/method=POST(...)*\/api\/users\/[\w.\-]*/)
        cnt_post_user += 1

        dynos[4] ||= Hash.new
        dynos[4] = count_dynos dynos[4], dyno

        request_times[4] ||= Array.new
        request_times[4] << total_time

        times[4] ||= Array.new
        times[4] = count_time times[4], total_time
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*/)
        cnt_get_user += 1

        dynos[5] ||= Hash.new
        dynos[5] = count_dynos dynos[5], dyno

        request_times[5] ||= Array.new
        request_times[5] << total_time

        times[5] ||= Array.new
        times[5] = count_time times[5], total_time
      end

      #dyno=web.8
      #unless dynos[dyno.to_sym].nil?
      #  dynos[dyno.to_sym] += 1
      #else
      #  dynos[dyno.to_sym] = 1
      #end

      #request_times << total_time

      #unless times[total_time].nil?
      #  times[total_time] += 1
      #else
      #  times[total_time] = 1
      #end
    end

    puts "Total entries: " + cnt_lines.to_s + ".\n\n"

    puts "GET /api/users/{user_id}/count_pending_messages called " + cnt_get_count_pending_messages.to_s + " times."
    puts "Busiest dyno: " + show_busiest_dynos(dynos[0]).to_s
    mean_time = find_mean_time request_times[0], cnt_lines
    mode = find_mode times[0]
    median = find_median mean_time, mode
    puts "Mean time: " + mean_time.to_s
    puts "Mode: " + mode.to_s
    puts "Median: " + median.to_s
    puts "\n\n"

    puts "GET /api/users/{user_id}/get_messages called " + cnt_get_messages.to_s + " times."
    puts "Busiest dyno: " + show_busiest_dynos(dynos[1]).to_s
    mean_time = find_mean_time request_times[1], cnt_lines
    mode = find_mode times[1]
    median = find_median mean_time, mode
    puts "Mean time: " + mean_time.to_s
    puts "Mode: " + mode.to_s
    puts "Median: " + median.to_s
    puts "\n\n"

    puts "GET /api/users/{user_id}/get_friends_progress called " + cnt_get_friends_progress.to_s + " times."
    puts "Busiest dyno: " + show_busiest_dynos(dynos[2]).to_s
    mean_time = find_mean_time request_times[2], cnt_lines
    mode = find_mode times[2]
    median = find_median mean_time, mode
    puts "Mean time: " + mean_time.to_s
    puts "Mode: " + mode.to_s
    puts "Median: " + median.to_s
    puts "\n\n"

    puts "GET /api/users/{user_id}/get_friends_score called " + cnt_get_friends_score.to_s + " times."
    puts "Busiest dyno: " + show_busiest_dynos(dynos[3]).to_s
    mean_time = find_mean_time request_times[3], cnt_lines
    mode = find_mode times[3]
    median = find_median mean_time, mode
    puts "Mean time: " + mean_time.to_s
    puts "Mode: " + mode.to_s
    puts "Median: " + median.to_s
    puts "\n\n"

    puts "POST /api/users/{user_id} called " + cnt_post_user.to_s + " times."
    puts "Busiest dyno: " + show_busiest_dynos(dynos[4]).to_s
    mean_time = find_mean_time request_times[4], cnt_lines
    mode = find_mode times[4]
    median = find_median mean_time, mode
    puts "Mean time: " + mean_time.to_s
    puts "Mode: " + mode.to_s
    puts "Median: " + median.to_s
    puts "\n\n"

    puts "GET /api/users/{user_id} called " + cnt_get_user.to_s + " times."
    puts "Busiest dyno: " + show_busiest_dynos(dynos[5]).to_s
    mean_time = find_mean_time request_times[5], cnt_lines
    mode = find_mode times[5]
    median = find_median mean_time, mode
    puts "Mean time: " + mean_time.to_s
    puts "Mode: " + mode.to_s
    puts "Median: " + median.to_s
    puts "\n\n"
  end
end

analyzer = HerokuLogsAnalyzer.new(*ARGV)
analyzer.do_analyze
