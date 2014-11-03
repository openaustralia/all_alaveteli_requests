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
    exit
  end
end

def all_request_urls
  agent = Mechanize.new

  url = "https://www.righttoknow.org.au/list/all"
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

#requests = ["https://www.righttoknow.org.au/request/the_socio_economic_impact_assess"]
requests = all_request_urls
secrets = load_secrets


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
      raise
    end
  end
end
