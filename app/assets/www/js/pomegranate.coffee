$ -> # document ready
  $(document).on "deviceready", -> # phonegap deviceready

    db = new PouchDB("Pomegranate")
# Check for most recent sms
    smsByTimeReceived = (doc) ->
      if doc.time_received
        emit(doc.time_received, null)

    saveResults = (results) ->
      _(results.texts).each (text) ->
        db.post text

    error = (error) ->
      console.log "Error: #{JSON.stringify error}"

    db.query
      map: smsByTimeReceived
      {
        reduce: false
        limit: 1
        include_docs: true
        descending: true
      }
      (error, response) ->
        console.log "error: #{JSON.stringify error}" if error
        console.log "response: #{JSON.stringify response}"
        if response.rows.length is 0
          console.log "No SMS's in DB, loading all SMSs on phone"
          cordova.exec saveResults, error , "ReadSms", "GetTexts", ["", -1] # No number specified, -1 is unlimited
        else
          cordova.exec saveResults, error , "ReadSms", "GetTextsAfter", ["", response.rows[0].time_received, -1] # No number specified, -1 is unlimited



    $("#send").click ->
      number = $("#phone_number").val()
      message = $("#message").val()

      success = -> alert "Message sent successfully"
      error = (e) -> alert "Message Failed:" + e

      cordova.exec success, error, "SmsPlugin", "SendSMS", [number, message]

    
    updateMessageTable = (results) ->
      $("#messages").html "
        <table>
          <thead>
            <th>from</th>
            <th>message</th>
            <th>date</th>
          </thead>
          <tbody>
            #{
              _(results.texts).map( (text) ->
                "
                  <tr>
                    <td>#{text.from}</td>
                    <td>#{text.message}</td>
                    <td>#{text.time_received}</td>
                  </tr>
                "
              ).join("")
            }
          </tbody>
        </table>
      "

    error = (error) ->
      console.log "THERE WAS AN ERROR!!! aaaaaAAAAHHHHH!!!"
      console.log error

    cordova.exec updateMessageTable, error, "ReadSms", "GetTexts", ["", -1] # No number specified, -1 is unlimited
