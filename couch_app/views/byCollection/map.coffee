(doc) ->
  return unless doc.collection?
  
  emit doc.collection, doc