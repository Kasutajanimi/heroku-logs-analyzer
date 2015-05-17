class HerokuLogsAnalyzer

  # Math links:
  # http://www.grandars.ru/student/statistika/strukturnye-srednie-velichiny.html
  # http://univer-nn.ru/statistika/moda-i-mediana/
  # http://www.wikihow.com/Calculate-Averages-(Mean,-Median,-Mode)

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

  def find_mode request_times
    mode = request_times.group_by{|e| e}.values.max_by(&:size).first
  end

  def find_mean_time request_times, cnt_lines
    mean_time = request_times.inject{|sum, x| sum + x }.to_f / cnt_lines
  end

  def find_median request_times
    request_times.sort!
    rank = 0.5*(request_times.size - 1)
    lower, upper = request_times[rank.floor, 2]
    median = lower + (upper - lower)*(rank - rank.floor)
  end

  def analyse_timings request_times, cnt_lines
    res = Hash.new
    res[:mean_time] = find_mean_time request_times, cnt_lines
    res[:median] = find_median request_times
    res[:mode] = find_mode request_times
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

  def process_line line_id, dyno, total_time
    @lines[line_id] ||= 0
    @lines[line_id] += 1

    @dynos[line_id] ||= Hash.new
    @dynos[line_id] = count_dynos @dynos[line_id], dyno

    @request_times[line_id] ||= Array.new
    @request_times[line_id] << total_time
  end

  def emit &block
    cnt_lines = 0

    @lines = Array.new
    @request_times = Array.new
    @dynos = Array.new # array of hashes

    @log_file.each_line do |line|
      cnt_lines += 1

      connect_time = line.match(/connect=[0-9]*ms/).to_s.split("=").last.split("ms").first
      service_time = line.match(/service=[0-9]*ms/).to_s.split("=").last.split("ms").first
      total_time = connect_time.to_i + service_time.to_i

      dyno = line.match(/dyno=web.[0-9]*/).to_s.split("=").last

      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/count_pending_messages/)
        process_line 0, dyno, total_time
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/get_messages/)
        process_line 1, dyno, total_time
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/get_friends_progress/)
        process_line 2, dyno, total_time
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*\/get_friends_score/)
        process_line 3, dyno, total_time
      end
      if line.match(/method=POST(...)*\/api\/users\/[\w.\-]*/)
        process_line 4, dyno, total_time
      end
      if line.match(/method=GET(...)*\/api\/users\/[\w.\-]*/)
        process_line 5, dyno, total_time
      end
    end

    @timings_data = Array.new

    (0..5).each do |i|
      @timings_data[i] = analyse_timings @request_times[i], @lines[i]
    end

    output = <<-EOT

      Heroku Logs Analyzer by Kasutajanimi, (c) 2015
      GitHub: https://github.com/Kasutajanimi/heroku-logs-analyzer

      Analysing #{@log_file.path}...

      Total queries: #{cnt_lines.to_s}

      1) GET "/api/users/{user_id}/count_pending_messages" called #{@lines[0].to_s} times.
      Busiest dynos: #{show_busiest_dynos(@dynos[0]).to_s}
      Mean time: #{@timings_data[0][:mean_time].to_s}
      Mode: #{@timings_data[0][:mode].to_s}
      Median: #{@timings_data[0][:median].to_s}

      2) GET "/api/users/{user_id}/get_messages" called #{@lines[1].to_s} times.
      Busiest dynos: #{show_busiest_dynos(@dynos[1]).to_s}
      Mean time: #{@timings_data[1][:mean_time].to_s}
      Mode: #{@timings_data[1][:mode].to_s}
      Median: #{@timings_data[1][:median].to_s}

      3) GET "/api/users/{user_id}/get_friends_progress" called #{@lines[2].to_s} times.
      Busiest dynos: #{show_busiest_dynos(@dynos[2]).to_s}
      Mean time: #{@timings_data[2][:mean_time].to_s}
      Mode: #{@timings_data[2][:mode].to_s}
      Median: #{@timings_data[2][:median].to_s}

      4) GET "/api/users/{user_id}/get_friends_score" called #{@lines[3].to_s} times.
      Busiest dynos: #{show_busiest_dynos(@dynos[3]).to_s}
      Mean time: #{@timings_data[3][:mean_time].to_s}
      Mode: #{@timings_data[3][:mode].to_s}
      Median: #{@timings_data[3][:median].to_s}

      5) POST "/api/users/{user_id}" called #{@lines[4].to_s} times.
      Busiest dynos: #{show_busiest_dynos(@dynos[4]).to_s}
      Mean time: #{@timings_data[4][:mean_time].to_s}
      Mode: #{@timings_data[4][:mode].to_s}
      Median: #{@timings_data[4][:median].to_s}

      6) GET "/api/users/{user_id}" called #{@lines[5].to_s} times.
      Busiest dynos: #{show_busiest_dynos(@dynos[5]).to_s}
      Mean time: #{@timings_data[5][:mean_time].to_s}
      Mode: #{@timings_data[5][:mode].to_s}
      Median: #{@timings_data[5][:median].to_s}

    EOT

    results_file_name = @log_file.path.gsub(".", "_").concat("_analyse_results.txt")

    puts output

    File.open(results_file_name, 'w') { |file| file.write(output) }
  end
end

analyzer = HerokuLogsAnalyzer.new(*ARGV)
analyzer.do_analyze
