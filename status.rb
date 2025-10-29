require 'net/http'
require 'uri'
require 'optparse'
require 'timeout'
require 'json'

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
  def initialize(input_file, output_file, verbose: false)
    @input_file = input_file
    @output_file = output_file
    @verbose = verbose
    @results = {
      metadata: {
        generated_at: Time.now.utc.iso8601,
        total_urls: 0,
        filtered_urls: 0,
        checked_urls: 0,
        successful_200: 0,
        forbidden_403: 0
      },
      websites: []
    }
    @checked_count = 0
    @total_urls = 0
    @filtered_count = 0
    
    @skip_extensions = [
      # Images
      '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.tiff', '.webp', '.svg', '.ico',
      # Documents
      '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.odt',
      # Media
      '.mp3', '.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm',
      # Fonts
      '.ttf', '.otf', '.woff', '.woff2', '.eot',
    ]
  end

  def check_websites
    urls = read_and_filter_urls
    @total_urls = urls.size
    @results[:metadata][:total_urls] = @total_urls
    @results[:metadata][:filtered_urls] = @filtered_count
    
    display_banner
    puts "🔍 #{'Checking websites...'.bold.cyan}"
    puts "📊 #{'Total URLs:'.bold} #{@total_urls.to_s.blue}"
    puts "🚫 #{'Filtered out:'.bold} #{@filtered_count.to_s.yellow}" if @filtered_count > 0
    puts "⏰ #{'Timeout:'.bold} 10 seconds per request"
    puts "💾 #{'Output:'.bold} JSON format (only 200 & 403)\n\n"
    
    show_loading_animation
    
    urls.each_with_index do |url, index|
      @checked_count = index + 1
      url = url.strip
      result = check_website_status(url)
      
      if @verbose
        display_status(url, result)
      else
        # Only show 200 and 403 in non-verbose mode
        if [200, 403].include?(result[:status])
          display_status(url, result)
        end
      end
      
      # Only store 200 and 403 status in results
      if [200, 403].include?(result[:status])
        website_data = {
          url: url,
          status: result[:status],
          timestamp: Time.now.utc.iso8601
        }
        
        if result[:status] == 200
          @results[:metadata][:successful_200] += 1
        elsif result[:status] == 403
          @results[:metadata][:forbidden_403] += 1
        end
        
        @results[:websites] << website_data
      end
      
      @results[:metadata][:checked_urls] = @checked_count
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
    #{'│'.blue} #{'Clean Output - Only 200 & 403'.cyan} #{'│'.blue.rjust(17)}
    #{'└' + '─' * 50 + '┘'.blue}
    BANNER
    puts banner
  end

  def show_loading_animation
    return unless @verbose
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
    return unless @verbose
    @loading = false
    @animation_thread.join if @animation_thread
    print "\r" + " " * 60 + "\r"
  end

  def read_and_filter_urls
    unless File.exist?(@input_file)
      puts "❌ #{'Error:'.bold.red} File #{@input_file.red} not found!"
      exit 1
    end
    
    urls = File.readlines(@input_file).map(&:chomp).reject(&:empty?)
    
    filtered_urls = urls.reject do |url|
      should_skip_url?(url)
    end
    
    @filtered_count = urls.size - filtered_urls.size
    
    if @verbose && @filtered_count > 0
      puts "🔍 #{'Filtering URLs...'.yellow}"
      urls.each do |url|
        if should_skip_url?(url)
          puts "🚫 #{'Skipped:'.bold.red} #{url}"
        end
      end
      puts ""
    end
    
    filtered_urls
  end

  def should_skip_url?(url)
    return true unless valid_url?(url)
    
    @skip_extensions.any? do |ext|
      url.downcase.include?(ext) || 
      url.downcase.end_with?(ext) ||
      URI.parse(url).path.downcase.end_with?(ext) rescue false
    end
  end

  def valid_url?(url)
    url =~ /\A#{URI::regexp(['http', 'https'])}\z/
  rescue URI::InvalidURIError
    false
  end

  def check_website_status(url)
    return { status: nil, error: "Invalid URL format" } unless valid_url?(url)
    
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
        return { status: response.code.to_i }
      end
    rescue Timeout::Error => e
      return { status: "TIMEOUT", error: "Request timed out after 10 seconds" }
    rescue SocketError => e
      return { status: "NETWORK_ERROR", error: "Network error: #{e.message}" }
    rescue => e
      return { status: "ERROR", error: e.message }
    end
  end

  def display_status(url, result)
    stop_loading_animation if @verbose
    
    status = result[:status]
    
    case status
    when 200
      puts "✅ #{'LIVE'.bold.green} #{url.cyan}"
    when 403
      puts "🔒 #{'FORBIDDEN'.bold.yellow} #{url.cyan}"
    when 404
      puts "❓ #{'NOT FOUND'.bold.blue} #{url.cyan}" if @verbose
    when 500..599
      puts "💥 #{'SERVER ERROR'.bold.red} #{url.cyan}" if @verbose
    when "TIMEOUT", "NETWORK_ERROR", "ERROR"
      puts "❌ #{'ERROR'.bold.red} #{url.cyan} (#{status})" if @verbose
    when nil
      puts "🚫 #{'INVALID'.bold.red} #{url.cyan}" if @verbose
    else
      puts "⚡ #{status.to_s.bold.magenta} #{url.cyan}" if @verbose && status.is_a?(Integer)
    end
    
    show_loading_animation if @verbose && @checked_count < @total_urls
  end

  def write_results_to_file
    # JSON sudah hanya berisi 200 dan 403 karena kita filter saat proses
    json_data = JSON.pretty_generate(@results, indent: '  ', space: ' ', object_nl: "\n")
    
    File.open(@output_file, 'w') do |file|
      file.write(json_data)
    end
  end

  def display_summary
    successful = @results[:metadata][:successful_200]
    forbidden = @results[:metadata][:forbidden_403]

    puts "\n"
    puts "┌#{'─' * 50}┐".green
    puts "│#{'📊 SCAN SUMMARY'.bold.center(50)}│".green
    puts "├#{'─' * 50}┤".green
    puts "│ #{'Total URLs in file:'.ljust(30)} #{@results[:metadata][:total_urls].to_s.rjust(18).blue} │".green
    puts "│ #{'Filtered out:'.ljust(30)} #{@filtered_count.to_s.rjust(18).yellow} │".green if @filtered_count > 0
    puts "│ #{'Checked URLs:'.ljust(30)} #{@checked_count.to_s.rjust(18).cyan} │".green
    puts "├#{'─' * 50}┤".green
    puts "│ #{'✅ Live (200):'.ljust(30)} #{successful.to_s.rjust(18).green} │".green
    puts "│ #{'🔒 Forbidden (403):'.ljust(30)} #{forbidden.to_s.rjust(18).yellow} │".green
    puts "└#{'─' * 50}┘".green
    
    puts "\n💾 #{'Clean results saved to:'.bold} #{@output_file.underline.cyan}"
    
    # Display only 200 and 403 findings
    if @results[:websites].any?
      puts "\n🎯 #{'INTERESTING FINDINGS:'.bold.magenta}"
      
      if successful > 0
        puts "\n#{'✅ Live Websites (200 OK):'.bold.green}"
        @results[:websites].select { |w| w[:status] == 200 }.each do |website|
          puts "  🔗 #{website[:url].cyan}"
        end
      end
      
      if forbidden > 0
        puts "\n#{'🔒 Forbidden (403):'.bold.yellow}"
        @results[:websites].select { |w| w[:status] == 403 }.each do |website|
          puts "  🔗 #{website[:url].cyan}"
        end
      end
    else
      puts "\n😔 #{'No websites with status 200 or 403 found.'.bold.red}"
    end
    
    puts "\n📋 #{'JSON Structure:'.bold}"
    puts "   📁 metadata - Scan information and statistics"
    puts "   📁 websites - Array of websites with status 200 & 403 only"
    puts "   ├── url: Website URL"
    puts "   ├── status: HTTP status (200 or 403)"
    puts "   └── timestamp: When the check was performed"
    
    puts "\n🎉 #{'Scan completed!'.bold.green}"
  end
end

options = {}
verbose = false

OptionParser.new do |opts|
  opts.banner = "Usage: #{'status.rb'.bold} #{'input_file.txt'.cyan} #{'-o output_file.json'.green} #{'[--verbose]'.yellow}"
  
  opts.on("-o", "--output FILE", "Output file (JSON format)") do |o|
    options[:output] = o
  end
  
  opts.on("-v", "--verbose", "Show verbose output (all requests)") do
    verbose = true
  end
  
  opts.on("-h", "--help", "Show this help message") do
    puts opts
    puts "\n#{'Examples:'.bold}"
    puts "  ruby status.rb websites.txt -o results.json"
    puts "  ruby status.rb urls.txt -o results.json --verbose"
    puts "\n#{'Features:'.bold}"
    puts "  🚫 Automatically filters images, PDFs, media files, etc."
    puts "  ✅ Output JSON only contains status 200 & 403"
    puts "  📋 Clean output showing only 200 & 403 results"
    puts "  🔍 Use --verbose to see all requests"
    exit
  end
end.parse!

if ARGV.empty? || !options[:output]
  puts "❌ #{'Usage:'.bold.red} #{'status.rb input_file.txt -o output_file.json'.yellow}"
  puts "   #{'Add --verbose to see all requests'.blue}"
  puts "   #{'Use -h for help'.blue}"
  exit 1
end

input_file = ARGV[0]
output_file = options[:output]

# Ensure output file has .json extension
output_file += ".json" unless output_file.downcase.end_with?('.json')

begin
  checker = WebsiteChecker.new(input_file, output_file, verbose: verbose)
  checker.check_websites
rescue Interrupt
  puts "\n\n⏹️  #{'Scan interrupted by user.'.bold.yellow}"
  exit 1
rescue => e
  puts "❌ #{'Unexpected error:'.bold.red} #{e.message}"
  exit 1
end