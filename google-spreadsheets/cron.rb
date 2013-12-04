require "rubygems"

require 'json'
require 'logger'
require 'rest-client'

require "google_drive"

require "./config.rb"

session = GoogleDrive.login $google[:user], $google[:pass]

def insertRow(columnArray, worksheetKey, session)

  ws = session.spreadsheet_by_key(worksheetKey).worksheets[0]

  blankRow = ws.num_rows + 1

  columnArray.each_with_index { | value, index |
    ws[blankRow, index+1] = value
  }

  ws.save()

end

def getUids(worksheetKey, session)

  ws = session.spreadsheet_by_key(worksheetKey).worksheets[0]

  result = []

  for row in 1..ws.num_rows
    result << ws[row, 1]
  end

  return result

end

# get uids from worksheet
docUids = getUids($google[:worksheetKey], session)

# get group names
groupNamesById = {}
groups = JSON.parse(RestClient.get("http://#{$couch[:user]}:#{$couch[:pass]}@#{$couch[:host]}/#{$couch[:database]}/_design/pomegranate/_view/byCollection?key=%22group%22&include_docs=true"))['rows'].map{|row| row['value']}
for group in groups
  groupNamesById[group["_id"]] = group["name"]
end

# get people
people = JSON.parse(RestClient.get("http://#{$couch[:user]}:#{$couch[:pass]}@#{$couch[:host]}/#{$couch[:database]}/_design/pomegranate/_view/peopleByGroup?include_docs=true"))['rows'].map{ |row| 
  row['value']['groupName'] = groupNamesById[row['key']]
  row['value']
}

# index people by phone
peopleByPhone = {}
for person in people
  peopleByPhone[person['phone']] = person
end

# get entire call log
csvRows = JSON.parse(RestClient.get("http://#{$couch[:user]}:#{$couch[:pass]}@#{$couch[:host]}/#{$couch[:database]}/_design/pomegranate/_view/csvRow"))['rows']

# insert when necessary
for row in csvRows
  rowUid = row['value']['uid']
  unless docUids.include? rowUid
    rows = row['value'].values
    rows.concat(peopleByPhone[row['value']['phone']]) unless peopleByPhone[row['value']['phone']].nil?
    insertRow rows, $google[:worksheetKey], session
  end
end
