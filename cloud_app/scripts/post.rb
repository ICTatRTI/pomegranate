#!/usr/bin/env ruby
# usage:
#   post.rb <live_form_url> arg1 arg2 arg3 ...

require "rest-client"

live_form_url = ARGV.shift
post_form_url = live_form_url.gsub(/viewform/,"formResponse")

params = RestClient.get(live_form_url).scan(/(entry\.\d+)/).flatten

options = {}
params.each do |param|
  options[param] = ARGV.shift
end

RestClient.post post_form_url, options


