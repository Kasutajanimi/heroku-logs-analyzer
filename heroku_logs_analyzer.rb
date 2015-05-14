args = *ARGV
@@debug_mode = false
if args.include? "debug=true"
  require "rubygems"
  require "descriptive_statistics"

  @@debug_mode = true
end

class HerokuLogsAnalyzer

  # Math proof:
  # http://www.grandars.ru/student/statistika/strukturnye-srednie-velichiny.html
  # http://univer-nn.ru/statistika/moda-i-mediana/

  TIME_INTERVAL_SIZE = 20

  def initialize log_path, *other
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
    max_time = times.length - 1

    i_start = 0
    i_end = TIME_INTERVAL_SIZE - 1
    avg_times = Array.new

    (0..max_time).step(TIME_INTERVAL_SIZE) do |i_start|
      i_end = i_start + TIME_INTERVAL_SIZE - 1
      avg_time = 0
      (i_start..i_end).each do |i|
        avg_time += i*times[i].to_i
      end
      avg_time /= TIME_INTERVAL_SIZE
      avg_times << avg_time
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

  def analyse_timings request_times, times, cnt_lines
    res = Hash.new
    res[:mean_time] = find_mean_time request_times, cnt_lines
    res[:mode] = find_mode times
    res[:median] = find_median res[:mean_time], res[:mode]
    res
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
    cnt_lines = 0

    lines = Array.new

    request_times = Array.new

    dynos = Array.new # array of hashes
    times = Array.new

    @log_file.each_line do |line|
      cnt_lines += 1

      connect_time = line.match(/connect=[0-9]*ms/).to_s.split("=").last.split("ms").first
      service_time = line.match(/service=[0-9]*ms/).to_s.split("=").last.split("ms").first
      total_time = connect_time.to_i + service_time.to_i

      dyno = line.match(/dyno=web.[0-9]*/).to_s.split("=").last

      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/count_pending_messages/)
        lines[0] ||= 0
        lines[0] += 1

        dynos[0] ||= Hash.new
        dynos[0] = count_dynos dynos[0], dyno

        request_times[0] ||= Array.new
        request_times[0] << total_time

        times[0] ||= Array.new
        times[0] = count_time times[0], total_time
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/get_messages/)
        lines[1] ||= 0
        lines[1] += 1

        dynos[1] ||= Hash.new
        dynos[1] = count_dynos dynos[1], dyno

        request_times[1] ||= Array.new
        request_times[1] << total_time

        times[1] ||= Array.new
        times[1] = count_time times[1], total_time
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/get_friends_progress/)
        lines[2] ||= 0
        lines[2] += 1

        dynos[2] ||= Hash.new
        dynos[2] = count_dynos dynos[2], dyno

        request_times[2] ||= Array.new
        request_times[2] << total_time

        times[2] ||= Array.new
        times[2] = count_time times[2], total_time
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/get_friends_score/)
        lines[3] ||= 0
        lines[3] += 1

        dynos[3] ||= Hash.new
        dynos[3] = count_dynos dynos[3], dyno

        request_times[3] ||= Array.new
        request_times[3] << total_time

        times[3] ||= Array.new
        times[3] = count_time times[3], total_time
      end
      if line.match(/method=POST(...)*\/api\/users\/[\w.\-]*/)
        lines[4] ||= 0
        lines[4] += 1

        dynos[4] ||= Hash.new
        dynos[4] = count_dynos dynos[4], dyno

        request_times[4] ||= Array.new
        request_times[4] << total_time

        times[4] ||= Array.new
        times[4] = count_time times[4], total_time
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*/)
        lines[5] ||= 0
        lines[5] += 1

        dynos[5] ||= Hash.new
        dynos[5] = count_dynos dynos[5], dyno

        request_times[5] ||= Array.new
        request_times[5] << total_time

        times[5] ||= Array.new
        times[5] = count_time times[5], total_time
      end
    end

    timings_data = Array.new

    (0..5).each do |i|
      timings_data[i] = analyse_timings request_times[i], times[i], lines[i]
    end

    output = <<-EOT

      #{"*** DEBUG MODE ***" if @@debug_mode}

      Heroku Logs Analyzer by Kasutajanimi, (c) 2015
      GitHub: https://github.com/Kasutajanimi/heroku-logs-analyzer

      Analysing #{@log_file.path}...

      Total queries: #{cnt_lines.to_s}

      1) GET "/api/users/{user_id}/count_pending_messages" called #{lines[0].to_s} times.
      Busiest dynos: #{show_busiest_dynos(dynos[0]).to_s}
      Mean time: #{timings_data[0][:mean_time].to_s}
      Mode: #{timings_data[0][:mode].to_s}
      Median: #{timings_data[0][:median].to_s}
      Debgug:
      DBG_Mean: #{request_times[0].mean}
      DBG_Median: #{request_times[0].median}
      DBG_Mode: #{request_times[0].mode}

      2) GET "/api/users/{user_id}/get_messages" called #{lines[1].to_s} times.
      Busiest dynos: #{show_busiest_dynos(dynos[1]).to_s}
      Mean time: #{timings_data[1][:mean_time].to_s}
      Mode: #{timings_data[1][:mode].to_s}
      Median: #{timings_data[1][:median].to_s}
      Debgug:
      DBG_Mean: #{request_times[1].mean}
      DBG_Median: #{request_times[1].median}
      DBG_Mode: #{request_times[1].mode}

      3) GET "/api/users/{user_id}/get_friends_progress" called #{lines[2].to_s} times.
      Busiest dynos: #{show_busiest_dynos(dynos[2]).to_s}
      Mean time: #{timings_data[2][:mean_time].to_s}
      Mode: #{timings_data[2][:mode].to_s}
      Median: #{timings_data[2][:median].to_s}
      Debgug:
      DBG_Mean: #{request_times[2].mean}
      DBG_Median: #{request_times[2].median}
      DBG_Mode: #{request_times[2].mode}

      4) GET "/api/users/{user_id}/get_friends_score" called #{lines[3].to_s} times.
      Busiest dynos: #{show_busiest_dynos(dynos[3]).to_s}
      Mean time: #{timings_data[3][:mean_time].to_s}
      Mode: #{timings_data[3][:mode].to_s}
      Median: #{timings_data[3][:median].to_s}
      Debgug:
      DBG_Mean: #{request_times[3].mean}
      DBG_Median: #{request_times[3].median}
      DBG_Mode: #{request_times[3].mode}

      5) POST "/api/users/{user_id}" called #{lines[4].to_s} times.
      Busiest dynos: #{show_busiest_dynos(dynos[4]).to_s}
      Mean time: #{timings_data[4][:mean_time].to_s}
      Mode: #{timings_data[4][:mode].to_s}
      Median: #{timings_data[4][:median].to_s}
      Debgug:
      DBG_Mean: #{request_times[4].mean}
      DBG_Median: #{request_times[4].median}
      DBG_Mode: #{request_times[4].mode}

      6) GET "/api/users/{user_id}" called #{lines[5].to_s} times.
      Busiest dynos: #{show_busiest_dynos(dynos[5]).to_s}
      Mean time: #{timings_data[5][:mean_time].to_s}
      Mode: #{timings_data[5][:mode].to_s}
      Median: #{timings_data[5][:median].to_s}
      Debgug:
      DBG_Mean: #{request_times[5].mean}
      DBG_Median: #{request_times[5].median}
      DBG_Mode: #{request_times[5].mode}

    EOT

    results_file_name = @log_file.path.gsub(".", "_").concat("_analyse_results.txt")

    puts output

    File.open(results_file_name, 'w') { |file| file.write(output) }
  end
end

analyzer = HerokuLogsAnalyzer.new(*ARGV)
analyzer.do_analyze
