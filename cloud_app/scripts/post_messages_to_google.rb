#!/usr/bin/env ruby
# usage:
#   post.rb <live_form_url> arg1 arg2 arg3 ...

require "rest-client"
require "couchrest"

database_url = ARGV.shift


@db = CouchRest.database(database_url)
google_form= @db.get("google_form")
@live_form_url = google_form["live_form_url"]

@google_form_params = google_form["form_params"]

def get_form_params
  form_params = RestClient.get(@live_form_url).scan(/(entry\.\d+)/).flatten
  google_form_doc = @db.get("google_form")
  google_form_doc["form_params"] = form_params
  @db.save_doc(google_form_doc)
  form_params
end

def post_to_google_forms(data)
  options = {}
  @google_form_params.each_with_index do |param,index|
    options[param] = data[index]
  end
  RestClient.post @live_form_url.gsub(/viewform/,"formResponse"), options
end


if @google_form_params.nil?
  @google_form_params = get_form_params()
end

# get all messages not marked as posted_to_google
@db.all_docs({:include_docs=>true})["rows"].each do |doc|
  doc = doc["doc"]
  if doc["message"] and not doc["posted_to_google"]
    puts "posting #{doc["message"]}"
    doc["posted_to_google"] = true
    @db.save_doc(doc)

    post_to_google_forms [doc["from"],doc["message"], doc["time_received"] ? "received" : "sent" ]
  end

end

