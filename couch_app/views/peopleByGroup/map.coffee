(doc) ->

  return unless doc.collection is "person"

  phone = doc.phone.replace(/[^0-9]/g, '')

  emit doc.groupId,
    phone       : phone
    name        : doc.name        || ''
    district    : doc.district    || ''
    designation : doc.designation || ''
    tags        : doc.tags        || ''