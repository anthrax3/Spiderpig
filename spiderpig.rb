#!/usr/bin/env ruby
#Give spiderpig a URL and it will download all .pdf and .doc documents and print the document metadata.
#Alternatively, give spiderpig a domain, and it will brute force subdomains, then spider each full domain found.
#It will then harvest metadata for each site.

#HIT LIST
########
#When i do ./spiderpig -h, trollop shows the file object ID - need to figure a better way of displaying this.
#Need to sort out the chdir stuff, its a bit ugly and makes it difficult to pass files in the same folder as an argument
#Need to sort printer so that it removes empty entries
#Have to stop it downloading all files on http, then on https etc. Dupes.
#Add a thing that says "hey you didn't specify a URL or Domain"
#Add proxy support
########
#END HIT LIST

require 'anemone'
require 'yomu'
require 'resolv'
require 'trollop'
require 'colorize'
require 'stringio'


foldername = Time.now.strftime("%d%b%Y_%H%M%S")
Dir.mkdir foldername
Dir.chdir foldername
$stderr.reopen("/dev/null", "w")

def arguments

opts = Trollop::options do 
  banner <<-EOS
 
EOS

  version "Spiderpig v0.5"
  opt :url, "Choose a specific site to spider - Ensure you include http:// etc.", :type => String
  opt :domain, "Choose a domain, we will perform sub domain brute forcing, then spider the results", :type => String
  opt :obey_robots, "Should we obey robots.txt? Default is true", :default => "True"
  opt :depth, "Spidering depth - Think before setting too large a value", :default => 2
  opt :user_agent, "Enter your own user agent string in double quotes!", :default => "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:40.0) Gecko/20100101 Firefox/40.1"
  opt :subdomains, "Provide your own list of subdomains", :default => File.open("../subdomains-top1mil-5000.txt", "r")
  opt :dns_server, "Provide a custom DNS server to use for subdomain lookups - Google resolver1 is the default", :default => "8.8.8.8"
  #Option to specify file type to download - May make this user configurable in the future??
  #currently won't accept file if it is in same directory due to dir changing. You have to provide the full path?? Needs to be fixed...
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
  Resolv.new(resolvers=[arg[:dns_server]]) #Could make these selectable using trollop - but set defaults.
    subdomain.chomp!
  ip = Resolv.getaddress "#{subdomain}.#{target}" rescue ""
    if ip != nil
      puts "#{subdomain}.#{target} \t #{ip}"
      subs << "http://#{subdomain}.#{target}"
      # subs << "https://#{subdomain}.#{target}" - assuming http sites have redirects to https....
    end
  end
end
subs
end

def download(arg, subdomains)
puts "Searching For Files on #{arg[:url]}".colorize(:red)
puts "Downloading Files:\n".colorize(:red)
#if robots.txt timeout - don't continue with that site???
#Also add in a file count
#if arg[:url] do X, elsif arg[:domain] do z
subdomains.each do |subs| #subdomains exist here, so the subdomains method is working.
Anemone.crawl(subs, :depth_limit => arg[:depth], :obey_robots_txt => arg[:obey_robots], :user_agent => arg[:user_agent], :skip_query_strings => true, :accept_cookies => true) do |anemone|
  anemone.on_pages_like(/\b.+.pdf/) do |page| #need multiple file types in here.
    begin
      filename = File.basename(page.url.request_uri.to_s)
      File.open(filename,"wb") {|f| f.write(page.body)}
      puts "#{page.url}"
    rescue
      puts "error while downloading #{page.url}"
        end
      end
    end
  end
end

def metadata(files)
  metadata = []
    puts "\nReading MetaData From Files - This may take some time!".colorize(:red)
    files.each do |file|
      puts "Processing #{file}".colorize(:green)
      Yomu.server(:metadata)
      metadata << Yomu.new(file).metadata
      Yomu.kill_server!
    end
 metadata
end

def printer(meta)
  puts "\nPotential Usernames (Document Creator)".colorize(:blue)
  puts meta.map { |h| h["Author"] }.uniq
  puts "\nSoftware Used to Create Documents".colorize(:blue)
  puts meta.map { |h| h["producer"] }.uniq
end

arg = arguments
subdomains = subdomains(arg)
download(arg, subdomains)
files = Dir["*.pdf"] #need to test what happens when no extension is provided. Will Tika be intelligent enough?
meta = metadata(files)
printer(meta)



####CODE GRAVEYARD BELOW. ABANDON HOPE ALL YE WHO ENTER HERE#######

# Required meta-data fields:
# Author
# meta:author
# Content-Type - pdf/doc etc
# Creation-Date
# Last-Modified
# Last-Save-Date
# producer
# xmp:CreatorTool
# Content-Location ??? This is in the tika docs but not Yomu. Might be file location?
# Keywords

