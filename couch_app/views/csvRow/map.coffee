(doc) ->
  return if not doc.message?
  result = {
    "to"       : doc.to            || ""
    "from"     : doc.from          || ""
    "received" : doc.time_received || ""
    "sent"     : doc.time_sent     || ""
    "message"  : doc.message
  }
  emit doc._id, result
