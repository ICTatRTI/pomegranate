(head, req) ->

  start
    "headers" : {
      "Content-Type": "text/csv; charset=UTF-8"
      "Content-Disposition": 
        if req.query.download == "false"
          ""
        else
          "attachment; filename=\"Haiti-#{(new Date()).getFullYear()}-#{(new Date()).getMonth()+1}-#{(new Date()).getDate()}.csv\""
    }

  #
  # Flatten and send column headings
  #

  first = true

  while row = getRow()

    oneRow = row.value

    if first
      columnNames = []
      columnNames.push("\"" + key + "\"") for key, value of oneRow
      send columnNames.join(",") + "\n"
      first = false

    csvRow = []
    for key, value of oneRow
      csvRow.push  '"' + String(value).replace(/"/g,'”') + '"'

    send csvRow.join(",") + "\n"

  return
