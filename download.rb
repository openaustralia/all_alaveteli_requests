#!/usr/bin/env ruby
#
# Download all visible requests from an Alaveteli site

# As far as I'm aware the api doesn't return more than a small number of the most recent requests
# and so it's not possible to use the api to get the urls for all the requests. So, instead
# we're going to scrape the pages. Yup.

require "mechanize"
require 'json'

def load_secrets
  if File.exists?(".secrets")
    YAML.load_file(".secrets")
  else
    puts "Create a file .secrets and put your Alaveteli email and password there like this:"
    puts 'email: YOUR@EMAIL'
    puts 'password: YOURPASSWORD'
    puts 'start:'
    puts '  year: YEAR_OF_FIRST_REQUEST_ON_YOUR_SITE'
    puts '  month: MONTH_OF_FIRST_REQUEST_ON_YOUR_SITE'
    exit
  end
end

def request_urls(url)
  agent = Mechanize.new

  links = []
  while url
    puts "Looking at page #{url}..."
    page = agent.get(url)
    links += page.search(".request_listing .head a").map do |a|
      uri = page.uri + a["href"]
      # We don't want the anchor part of the url
      uri.fragment = nil
      uri.to_s
    end
    n = page.at("a[rel='next']")
    if n
      url = (page.uri + n["href"]).to_s
    else
      url = nil
    end
  end
  links
end

def all_request_urls(start_date)
  links = []
  # First request was in October 2012
  from_date = start_date
  while from_date <= Date.today
    links += request_urls("https://www.righttoknow.org.au/list/all?request_date_after=#{from_date.strftime('%Y/%m/%d')}&request_date_before=#{from_date.next_month.strftime('%Y/%m/%d')}")
    from_date = from_date.next_month
  end
  links.uniq
end

secrets = load_secrets

if File.exists?("data/downloaded")
  puts "Skipping the downloading because we've already finished that"
else
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

  requests = all_request_urls(Date.new(secrets["start"]["year"], secrets["start"]["month"], 1))

  agent = Mechanize.new
  page = agent.get("https://www.righttoknow.org.au/profile/sign_in")
  form = page.form_with(id: "signin_form")
  email_field = form.field_with(name: "user_signin[email]")
  password_field = form.field_with(name: "user_signin[password]")
  email_field.value = secrets["email"]
  password_field.value = secrets["password"]
  page = form.submit

  # First need to login because we can't download the zip file without being logged in

  requests.each do |request|
    json = agent.get("#{request}.json").body.to_s
    page = JSON.parse(json)
    id = page["id"]
    if File.exists?("data/#{id}")
      puts "Skipping request #{id}. Already downloaded."
    else
      puts "Downloading data for request #{id}..."
      begin
        # Create a directory based on the id
        FileUtils.mkdir_p("data/#{id}")
        File.open("data/#{id}/request.json", "w") {|f| f.write(json)}
        zip = agent.get("#{request}/download").body
        File.open("data/#{id}/download.zip", "w") {|f| f.write(zip)}
      rescue
        # Any problems just delete the whole directory
        FileUtils.rm_rf("data/#{id}")
        puts "Something went wrong... Let's just continue"
        #raise
      end
      puts "Done"
    end
  end

  FileUtils.touch("data/downloaded")
end

if File.exists?("data/unzipped")
  puts "Skipping unzipping because we've already done it"
else
  Dir.entries("data").each do |entry|
    if entry != "." && entry != ".." && entry != "downloaded"
      FileUtils.mkdir("data/#{entry}/download")
      Dir.chdir("data/#{entry}/download") do
        puts "Unzipping data/#{entry}/download.zip"
        system("unzip ../download.zip")
      end
    end
  end
  FileUtils.touch("data/unzipped")
end

if File.exists?("data/documents")
  puts "Already moved documents into one directory"
else
  # Copy all unzipped files into one directory
  FileUtils.mkdir("data/documents")

  Dir.entries("data").each do |entry|
    if entry != "." && entry != ".." && entry != "downloaded" && entry != "unzipped" && entry != "documents"
      puts "Copying contents of #{entry}..."
      Dir.entries("data/#{entry}/download").each do |entry2|
        if entry2 != "." && entry2 != ".."
          FileUtils.cp("data/#{entry}/download/#{entry2}", "data/documents/#{entry}_#{entry2.gsub(' ','_')}")
        end
      end
    end
  end
end

# Clean out some specific files that are of no relevance or in a weird file format that we can't convert
FileUtils.rm_f ("data/documents/459_1_3_attachment.delivery_status")
FileUtils.rm_rf("data/documents/28_1_3_image001.wmz")

# All images are just email filler. So removing them with a few exceptions (gone through these by hand)
not_delete = [
  "444_6_3_attachment.gif",
  "444_6_4_attachment.gif",
  "444_6_5_attachment.gif",
  "444_6_6_attachment.gif",
  "444_6_7_attachment.gif",
  "444_6_8_attachment.gif",
  "444_6_9_attachment.gif",
  "444_6_10_attachment.gif",
  "684_4_5_image008.png",
  "684_4_6_image009.png",
  "684_4_7_image015.png"
].map{|a| "data/documents/#{a}"}

#png, jpg, gif

files = Dir.glob("data/documents/*.gif") + Dir.glob("data/documents/*.png") + Dir.glob("data/documents/*.jpg")
files.each do |entry|
  FileUtils.rm(entry) unless not_delete.include?(entry)
end

# Remove stupid text disclaimers
Dir.glob("data/documents/*disclaimer*").each do |entry|
  FileUtils.rm(entry)
end

documents = Dir.entries("data/documents")
documents.delete('.')
documents.delete('..')

documents_by_type = {}
documents.each do |d|
  type = `file --mime-type -b data/documents/#{d}`.strip
  documents_by_type[type] ||= []
  documents_by_type[type] << d
end
puts documents_by_type.to_yaml
