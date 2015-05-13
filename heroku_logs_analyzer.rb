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

  def emit &block
    cnt_get_count_pending_messages = 0
    cnt_get_messages = 0
    cnt_get_friends_progress = 0
    cnt_get_friends_score = 0
    cnt_post_user = 0
    cnt_get_user = 0
    cnt_lines = 0

    request_times = Array.new

    dynos = Hash.new
    times = Array.new

    @log_file.each_line do |line|
      cnt_lines += 1
      #yield line
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/count_pending_messages/)
        #yield line
        cnt_get_count_pending_messages += 1
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/get_messages/)
        cnt_get_messages += 1
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/get_friends_progress/)
        cnt_get_friends_progress += 1
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/get_friends_score/)
        cnt_get_friends_score += 1
      end
      if line.match(/method=POST(...)*\/api\/users\/[\w.\-]*/)
        cnt_post_user += 1
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*/)
        cnt_get_user += 1
      end

      dyno = line.match(/dyno=web.[0-9]*/).to_s.split("=").last
      #dyno=web.8
      unless dynos[dyno.to_sym].nil?
        dynos[dyno.to_sym] += 1
      else
        dynos[dyno.to_sym] = 1
      end

      connect_time = line.match(/connect=[0-9]*ms/).to_s.split("=").last.split("ms").first
      service_time = line.match(/service=[0-9]*ms/).to_s.split("=").last.split("ms").first
      total_time = connect_time.to_i + service_time.to_i

      request_times << total_time

      unless times[total_time].nil?
        times[total_time] += 1
      else
        times[total_time] = 1
      end
    end

    puts "Total entries: " + cnt_lines.to_s + "."
    puts "GET /api/users/{user_id}/count_pending_messages called " + cnt_get_count_pending_messages.to_s + " times."
    puts "GET /api/users/{user_id}/get_messages called " + cnt_get_messages.to_s + " times."
    puts "GET /api/users/{user_id}/get_friends_progress called " + cnt_get_friends_progress.to_s + " times."
    puts "GET /api/users/{user_id}/get_friends_score called " + cnt_get_friends_score.to_s + " times."
    puts "POST /api/users/{user_id} called " + cnt_post_user.to_s + " times."
    puts "GET /api/users/{user_id} called " + cnt_get_user.to_s + " times."
    #dynos[:"web.44"] = 909
    puts "Busiest dyno: " + show_busiest_dynos(dynos).to_s
    mean_time = find_mean_time request_times, cnt_lines
    mode = find_mode times
    median = find_median mean_time, mode
    puts "Mean time: " + mean_time.to_s
    puts "Mode: " + mode.to_s
    puts "Median: " + median.to_s
  end
end

analyzer = HerokuLogsAnalyzer.new(*ARGV)
analyzer.do_analyze
