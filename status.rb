require 'net/http'
require 'uri'
require 'optparse'
require 'timeout'

class String
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red; colorize(31); end
  def green; colorize(32); end
  def yellow; colorize(33); end
  def blue; colorize(34); end
  def magenta; colorize(35); end
  def cyan; colorize(36); end
  def bold; colorize(1); end
  def underline; colorize(4); end
end

class WebsiteChecker
  def initialize(input_file, output_file)
    @input_file = input_file
    @output_file = output_file
    @results = []
    @checked_count = 0
    @total_urls = 0
  end

  def check_websites
    urls = read_urls_from_file
    @total_urls = urls.size
    
    display_banner
    puts "🔍 #{'Checking websites...'.bold.cyan}"
    puts "📊 #{'Total URLs:'.bold} #{@total_urls.to_s.blue}"
    puts "⏰ #{'Timeout:'.bold} 10 seconds per request\n\n"
    
    show_loading_animation
    
    urls.each_with_index do |url, index|
      @checked_count = index + 1
      status = check_website_status(url.strip)
      display_status(url.strip, status)
      
      if [200, 403].include?(status)
        @results << { url: url.strip, status: status }
      end
    end
    
    stop_loading_animation
    write_results_to_file
    display_summary
  end

  private

  def display_banner
    banner = <<~BANNER
    #{'┌' + '─' * 50 + '┐'.blue}
    #{'│'.blue} #{'🌐 WEBSITE STATUS CHECKER'.bold.magenta} #{'│'.blue.rjust(23)}
    #{'│'.blue} #{'Automated HTTP Status Scanner'.cyan} #{'│'.blue.rjust(18)}
    #{'└' + '─' * 50 + '┘'.blue}
    BANNER
    puts banner
  end

  def show_loading_animation
    @loading = true
    @animation_thread = Thread.new do
      chars = ['⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷']
      i = 0
      while @loading
        print "\r#{'Scanning:'.bold.yellow} #{chars[i % chars.length]} #{'Progress:'.bold} #{@checked_count}/#{@total_urls} "
        i += 1
        sleep 0.1
      end
    end
  end

  def stop_loading_animation
    @loading = false
    @animation_thread.join if @animation_thread
    print "\r" + " " * 60 + "\r"
  end

  def read_urls_from_file
    unless File.exist?(@input_file)
      puts "❌ #{'Error:'.bold.red} File #{@input_file.red} not found!"
      exit 1
    end
    
    File.readlines(@input_file).map(&:chomp).reject(&:empty?)
  end

  def check_website_status(url)
    return nil unless valid_url?(url)
    
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'Mozilla/5.0 (Website Status Checker)'
    
    begin
      Timeout.timeout(10) do
        response = http.request(request)
        return response.code.to_i
      end
    rescue Timeout::Error
      return "TIMEOUT"
    rescue SocketError => e
      return "NETWORK_ERROR"
    rescue => e
      return "ERROR"
    end
  end

  def valid_url?(url)
    url =~ /\A#{URI::regexp(['http', 'https'])}\z/
  end

  def display_status(url, status)
    stop_loading_animation
    
    status_text = case status
    when 200
      "✅ #{'200 OK'.bold.green}"
    when 403
      "🔒 #{'403 FORBIDDEN'.bold.yellow}"
    when "TIMEOUT"
      "⏰ #{'TIMEOUT'.bold.red}"
    when "NETWORK_ERROR"
      "🌐 #{'NETWORK ERROR'.bold.red}"
    when "ERROR"
      "❌ #{'ERROR'.bold.red}"
    when nil
      "🚫 #{'INVALID URL'.bold.red}"
    else
      "⚡ #{status.to_s.bold.blue}"
    end
    
    puts "📡 #{url.ljust(50)} → #{status_text}"
    
    show_loading_animation if @checked_count < @total_urls
  end

  def write_results_to_file
    File.open(@output_file, 'w') do |file|
      file.puts "# Website Status Check Results"
      file.puts "# Generated: #{Time.now}"
      file.puts "# Total checked: #{@total_urls}"
      file.puts "# Filter: 200, 403"
      file.puts "# Found: #{@results.size}"
      file.puts ""
      
      @results.each do |result|
        file.puts "#{result[:url]}\t#{result[:status]}"
      end
    end
  end

  def display_summary
    puts "\n"
    puts "┌#{'─' * 50}┐".green
    puts "│#{'📊 SCAN SUMMARY'.bold.center(50)}│".green
    puts "├#{'─' * 50}┤".green
    puts "│ #{'Total URLs checked:'.ljust(30)} #{@total_urls.to_s.rjust(18).blue} │".green
    puts "│ #{'Successful (200):'.ljust(30)} #{@results.count { |r| r[:status] == 200 }.to_s.rjust(18).green} │".green
    puts "│ #{'Forbidden (403):'.ljust(30)} #{@results.count { |r| r[:status] == 403 }.to_s.rjust(18).yellow} │".green
    puts "│ #{'Other status/errors:'.ljust(30)} #{(@total_urls - @results.size).to_s.rjust(18).red} │".green
    puts "└#{'─' * 50}┘".green
    
    puts "\n💾 #{'Results saved to:'.bold} #{@output_file.underline.cyan}"
    
    if @results.any?
      puts "\n🎯 #{'MATCHED WEBSITES:'.bold.magenta}"
      @results.each do |result|
        status_icon = result[:status] == 200 ? "✅" : "🔒"
        puts "  #{status_icon} #{result[:url].cyan} #{'(200 OK)'.green}" if result[:status] == 200
        puts "  #{status_icon} #{result[:url].cyan} #{'(403 Forbidden)'.yellow}" if result[:status] == 403
      end
    else
      puts "\n😔 #{'No websites with status 200 or 403 found.'.bold.red}"
    end
    
    puts "\n🎉 #{'Scan completed!'.bold.green}"
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{'status.rb'.bold} #{'input_file.txt'.cyan} #{'-o output_file.txt'.green}"
  
  opts.on("-o", "--output FILE", "Output file") do |o|
    options[:output] = o
  end
  
  opts.on("-h", "--help", "Show this help message") do
    puts opts
    puts "\n#{'Examples:'.bold}"
    puts "  ruby status.rb websites.txt -o results.txt"
    puts "  ruby status.rb urls.txt -o filtered.txt"
    exit
  end
end.parse!

if ARGV.empty? || !options[:output]
  puts "❌ #{'Usage:'.bold.red} #{'status.rb input_file.txt -o output_file.txt'.yellow}"
  puts "   #{'Use -h for help'.blue}"
  exit 1
end

input_file = ARGV[0]
output_file = options[:output]

begin
  checker = WebsiteChecker.new(input_file, output_file)
  checker.check_websites
rescue Interrupt
  puts "\n\n⏹️  #{'Scan interrupted by user.'.bold.yellow}"
  exit 1
rescue => e
  puts "❌ #{'Unexpected error:'.bold.red} #{e.message}"
  exit 1
end