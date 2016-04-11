#!/usr/bin/env ruby
#https://github.com/hatlord/Spiderpig

require 'anemone'
require 'yomu'
require 'resolv'
require 'trollop'
require 'colorize'
require 'luhn'
require 'ipaddress'
require 'exiftool'
require 'exiftool_vendored'

banner = <<-OINK
┈┈┏━╮╭━┓┈╭━━━━━━━━━━━━━━━━╮
┈┈┃┏┗┛┓┃╭┫SpiderPig v0.95b┃
┈┈╰┓▋▋┏╯╯╰━━━━━━━━━━━━━━━━╯
┈╭━┻╮╲┗━━━━╮╭╮┈
┈┃▎▎┃╲╲╲╲╲╲┣━╯┈
┈╰━┳┻▅╯╲╲╲╲┃┈┈┈
┈┈┈╰━┳┓┏┳┓┏╯┈┈┈
┈┈┈┈┈┗┻┛┗┻┛┈┈┈┈
OINK
puts banner.light_magenta


@foldername = Time.now.strftime("%d%b%Y_%H%M%S")
Dir.mkdir @foldername
$stderr.reopen("/dev/null", "w")

def arguments

opts = Trollop::options do 
  version "Spiderpig v0.95beta".light_blue
  banner <<-EOS
  
  Spiderpig is a document metadata harvester that relies on active spidering to find its documents. This is to
  provide an alternative to harvesters that use search results to identify documents. It requires either a full URL
  or a domain name. If you provide a domain name, it will do sub-domain brute forcing and then spider each site it finds.
  You can either use the default sub-domains file, or specify your own with a full path to that file.
  Examples:
  Test a URL:
  ./spiderpig.rb -u http://www.website.com
  Test a domain - This will do sub-domain enumeration with the default subs file:
  ./spiderpig.rb -d website.com
  Test domain with your own sub-domain file:
  ./spiderpig.rb -d website.com -b mysubsfile.txt
 
EOS

  opt :url, "Choose a specific site to spider - Ensure you include http:// etc.", :type => String
  opt :domain, "Choose a domain. We will perform sub domain brute forcing, then spider the results", :type => String
  opt :obey_robots, "Should we obey robots.txt? Default is true", :default => "True"
  opt :depth, "Spidering depth - Think before setting too large a value", :default => 2
  opt :user_agent, "Enter your own user agent string in double quotes!", :default => "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:40.0) Gecko/20100101 Firefox/40.1"
  opt :subdomains, "subs", :default => "domains.txt"
  opt :dns_server, "Provide a custom DNS server to use for subdomain lookups - Google resolver1 is the default", :default => "8.8.8.8"
  opt :proxy, "Specify a proxy server", :default => nil
  opt :proxyp, "Specify a proxy port", :default => nil
  opt :dirtmode, "Dig within documents for sensitive data. Currently IPs, credit card numbers, emails"
  opt :passlist, "Builds a wordlist from the content of all downloaded documents. Must be used with --dirtmode"
  opt :exif, "Downloads image files and parses them for Exif GeoTags"
  opt :offline, "Harvest Files You Already Have"

    if ARGV.empty?
      puts "Need Help? Try ./spiderpig --help or -h"
      exit
    end
  end
opts
end

def subdomains(arg)
  subs = []
    
    if arg[:domain]
      subs << arg[:domain]
    end
    if arg[:url]
      subs << arg[:url]
    end
  
  target = arg[:domain]
    if arg[:domain]
      puts "Subdomain enumeration for #{target} beginning at #{Time.now.strftime("%H:%M:%S")}"

  File.open(arg[:subdomains],"r").each_line do |subdomain|
    Resolv.new(resolvers=[arg[:dns_server]])
      subdomain.chomp!
    ip = Resolv.getaddress "#{subdomain}.#{target}" rescue ""
      if ip != nil
        puts "#{subdomain}.#{target} \t #{ip}"
      subs << "http://#{subdomain}.#{target}"
      end
    end
  end
subs
end

def download(arg, subdomains)
  
  if !arg[:exif]
    doc = /\b.+.pdf|\b.+.doc$|\b.+.docx$|\b.+.xls$|\b.+.xlsx$|\b.+.pages/i
  else
    doc = /\b.+.jpg|\b.+.tiff/i
  end
  if arg[:url]
    puts "\nSearching For Files on #{arg[:url]}".red
  end
  if arg[:domain]
    puts "\nSearching For Files on #{arg[:domain]} subdomains".red
  end

puts "Downloading Files:\n".red
subdomains.each do |subs| 
  Anemone.crawl(
    subs,
    :depth_limit => arg[:depth], 
    :obey_robots_txt => arg[:obey_robots],
    :user_agent => arg[:user_agent],
    :proxy_host => arg[:proxy],
    :proxy_port => arg[:proxyp],
    :accept_cookies => true,
    :skip_query_strings => true
  ) do |anemone|
      anemone.on_pages_like(doc) do |page|
        begin
          filename = File.basename(page.url.request_uri.to_s)
          File.open("#{@foldername}/#{filename}","wb") {|f| f.write(page.body)}
          puts "#{page.url}"
        rescue
          puts "error while downloading #{page.url}"
        end
      end
    end
  end
end

def metadata(files, arg)
  metadata = []
  port = rand(54000..59000)
   
    if !files.empty? and !arg[:exif]
    Yomu.server(:metadata, custom_port = port)
    puts "\nReading MetaData From Files - This may take some time!\n".red
    files.each do |file|
      puts "Processing #{file}".green
      metadata << Yomu.new(file).metadata
      end
    Yomu.kill_server!
  end
  metadata
end

def filecontent(files, arg)
  alltext = []
  port = rand(60000..65000)

  if arg[:dirtmode]
  if !files.empty? and !arg[:exif]
    Yomu.server(:text, custom_port = port)
    files.each do |file|
      hash = {}
        hash[file] = Yomu.new(file).text
        alltext << hash
      end
    Yomu.kill_server!
    end
  alltext
  end
end

def emails(content, arg)
  email_regex = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}/i

  if arg[:dirtmode]
  puts "\nEmail addresses found in documents:".light_blue
  
  content.each do |z|
    z.each do |k, v|
      email = v.to_s.scan email_regex
      email.uniq!
      if !email.empty?
        puts "\n" + k.to_s + "\n" + email.join("\n").cyan
      end
    end
  end
end
end

def ipaddr(content, arg)
  ip_regex = /\d+\.\d+\.\d+\.\d+/

  if arg[:dirtmode]
    puts "\nPossible IP Addresses found in documents:".light_blue

  content.each do |z|
    z.each do |k, v|
      ip = v.to_s.scan ip_regex
      ip.uniq!
      ip.keep_if { |ip| IPAddress.valid? ip }
      if !ip.empty?
        puts "\n" + k.to_s + "\n" + ip.join("\n").cyan
      end
    end
  end
end
end

def cc(content, arg)
  cc_regex =  /\b(?:\d[ -]*?){13,16}\b/
  
  if arg[:dirtmode]
    puts "\nPossible Credit Card Number Found!!".light_blue

  content.each do |z|
    z.each do |k, v|
      cc = v.to_s.scan cc_regex
      cc.uniq!
      cc.each { |card| card.gsub!(/-| /, "") }
      cc.keep_if { |card| Luhn.valid? card }
      if !cc.empty?
        puts "\n" + k.to_s + "\n" + cc.join("\n").cyan
      end
    end
  end
end
end

def passlist(content, arg)
  if arg[:passlist]
    puts "\npasslist.txt generated".light_blue

  content.each do |z|
    z.each do |k, v|
      words =  v.to_s.scan /\w+/
      words.uniq!
      if !words.empty?
        out_file = File.new("#{@foldername}/passlist.txt", "w")
          out_file.puts "\n" + words.join("\n").cyan
        out_file.close
      end
    end
  end
end
end

def keywords(content, arg)
  if arg[:dirtmode]
    wordarr = []
    file = File.open("keywords.txt") do |f|
      f.each_line do |line|
        wordarr << line
      end
    puts "\nPotentially Sensitive Data In Document(s)".light_blue
  
    content.each do |z|
      z.each do |k, v|
        wordarr.each do |w|
        keywords = v.to_s.scan /#{w}/i
        keywords.uniq!
        if !keywords.empty?
          printf "%-50s %s", k, keywords.join("").cyan
          end
        end
      end
    end
  end
end
end

def exif(files, arg)
  exifarray = []
  exifarray << "ImageName,Latitude,Longitude"

  if arg[:exif]
    if !files.empty?
      files.each do |z|
        exif = Exiftool.new(z)
        exifh = exif.to_hash
        if exifh.has_key?(:gps_latitude)
          exifarray << "#{exifh[:file_name]},#{exifh[:gps_latitude]},#{exifh[:gps_longitude]}"
          puts "#{"\n" + exifh[:file_name].light_blue + "\n" + exifh[:gps_latitude].to_s.yellow + " " + exifh[:gps_longitude].to_s.magenta}"
        else
          puts "#{"\n" + exifh[:file_name]} ***Image did not contain GPS data***".red
        end
        if exifh.has_key?(:make)
          puts "#{exifh[:make] + ' ' + exifh[:model] + ' ' + exifh[:software].to_s}".green
        end
      end
      gmaps = File.new("#{@foldername}/gmaps.csv", "w")
      gmaps.puts exifarray
      gmaps.close
      puts "\nGoogle Maps Compatible CSV Written to #{@foldername}/gmaps.csv".light_blue
    end
  end
end

def printer(meta, arg)
  if meta != nil and !arg[:exif]
    puts "\nPotential Usernames (Document Creator)".light_blue
    puts meta.map { |h| h["Author"] }.compact.reject(&:empty?).uniq
    puts "\nSoftware Used to Create Documents".light_blue
    puts meta.map { |h| h["producer"] }.compact.reject(&:empty?).uniq
    puts meta.map { |h| h["Application-Name"] }.compact.reject(&:empty?).uniq
  end
end

arg = arguments
subdomains = subdomains(arg)
download(arg, subdomains)
numfiles = Dir["#{@foldername}/*"].length
puts "Number of Files Downloaded: #{numfiles}".light_blue
if arg[:offline]
  files = Dir.glob(ARGV[0] + '/*.*')
else
  files = Dir.glob("#{@foldername}/*")
end
meta = metadata(files, arg)
content = filecontent(files, arg)
emails(content, arg)
ipaddr(content, arg)
cc(content, arg)
keywords(content, arg)
exif(files, arg)
printer(meta, arg)
passlist(content, arg)