(doc) ->

  return if not doc.message?

  phoneFrom = (doc.from ||'').replace(/[^0-9]/g, '')
  phoneTo   = (doc.to   ||'').replace(/[^0-9]/g, '')

  emit doc._id,
    "uid" : doc._id

    "to"   : phoneTo   || "pom phone"
    "from" : phoneFrom || "pom phone"

    "timeReceived" : doc.time_received || ""
    "timeSent"     : doc.time_sent     || ""

    "sentMessage"     : typeof doc.to is "string"
    "receivedMessage" : typeof doc.from is "string"

    "message" : doc.message


