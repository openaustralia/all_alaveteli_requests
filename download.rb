#!/usr/bin/env ruby
#
# Download all visible requests from an Alaveteli site

# As far as I'm aware the api doesn't return more than a small number of the most recent requests
# and so it's not possible to use the api to get the urls for all the requests. So, instead
# we're going to scrape the pages. Yup.

require "mechanize"

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

p all_request_urls
