$ -> # document ready
  $(document).on "deviceready", -> # phonegap deviceready

    cordova.execute = (options) ->
      cordova.exec options.success, options.error , options.plugin.name, options.plugin.function, options.plugin.args

    db = new PouchDB("Pomegranate")

    # Views
    #
    smsByTimeReceived = (doc) ->
      if doc.time_received
        emit(doc.time_received, null)

    smsReceivedButNotProcessed = (doc) ->
      if doc.time_received and not doc.processed
        emit(doc.time_received, null)

    smsToSend = (doc) ->
      if doc.time_created and not doc.processed
        emit(doc.time_created, null)

    # Utility functions
    saveResults = (results) ->
      _(results.texts).each (text) ->
        # Make this deterministic to allow for syncing after deleting the database locally (and syncing with cloud)
        text._id = "#{text.time_received}+#{text.from}"
        db.put text

    getAllSmsSaveInDB = ->
      cordova.execute
        success: saveResults
        error: (error) ->
          console.log "Error while saving: #{JSON.stringify error}"
        plugin:
          name: "ReadSms"
          function: "GetTexts"
          args: ["",-1]

    getAllSmsAfterCutoffSaveInDB = (cutoff) ->
      #cordova.exec saveResults, error , "ReadSms", "GetTextsAfter", ["", response.rows[0].time_received, -1] # No number specified, -1 is unlimited
      cordova.execute
        success: saveResults
        error: (error) ->
          console.log "Error while saving: #{JSON.stringify error}"
        plugin:
          name: "ReadSms"
          function: "GetTextsAfter"
          args: ["", cutoff, -1]

    error = (error) ->
      console.log "Error: #{JSON.stringify error}"

    # Check the db for the most recent SMS
    # Then add any new ones on the phone to it
    db.query
      map: smsByTimeReceived
      {
        reduce: false
        limit: 1
        include_docs: true
        descending: true
      }
      (error, response) ->
        
        if response.rows.length is 0
          console.log "No SMS's in DB, loading all SMSs on phone"
          getAllSmsSaveInDB()
        else
          console.log "Getting messages after #{response.rows[0].time_received} and adding them to DB"
          getAllSmsAfterCutoffSaveInDB(response.rows[0].time_received)

    db.changes
#      since: 20
#      TODO figure out how to use since - sequence numbers?
      continuous: true
      include_docs: true
      filter: smsToSend
      onChange: (doc) ->
        console.log "Change: #{doc}"
        cordova.execute
          success: ->
            console.log "SMS sent: #{JSON.stringify doc}"
            doc.processed = true
            db.put doc
          error: (error) ->
            console.log "Error on sending SMS: #{JSON.stringify doc}, error: #{JSON.stringify error}"
          plugin:
            name: "SmsPlugin"
            function: "SendSMS"
            args: [doc.to, doc.message]

    $("#send").click ->
      doc.to = $("#to")
      doc.message = $("#message")
      doc.time_created = Date.now()
      doc._id = "#{doc.time_received}+#{text.to}"
      db.put doc # should trigger changes callback

    PouchDB.replicate 'pomegranate', 'http://mikeymckay.iriscouch.com/pomegranate',
      continuous: true
    PouchDB.replicate 'http://mikeymckay.iriscouch.com/pomegranate','pomegranate',
      continuous: true
