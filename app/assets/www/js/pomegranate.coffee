$ -> # document ready

  Pomegranate =
    config:
      database_name: "pomegranate"
      remote_url: "http://mikeymckay.iriscouch.com/pomegranate"
      number_of_past_days_to_store_in_db: 10

  $(document).on "deviceready", -> # phonegap deviceready

    cordova.execute = (options) ->
      cordova.exec options.success, options.error , options.plugin.name, options.plugin.function, options.plugin.args


    # Views
    #
    smsByTimeReceived = (doc) ->
      if doc.time_received
        emit(doc.time_received, null)

    # Utility functions
    log = (message) ->
      console.log message
      $("#log").prepend message + "<br/>"

    saveResults = (results) ->
      if results.texts.length isnt 0
        db.bulkDocs
          docs: _(results.texts).map (text) ->
            # Make this deterministic to allow for syncing after deleting the database locally (and syncing with cloud)
            text._id = "#{text.time_received}+#{text.from}"
            text
        , (error, response) ->
          log "Error while bulk savings: #{JSON.stringify error}" if error?
          log "Saved #{response.length} items" if response?

    getAllSmsSaveInDB = ->
      cordova.execute
        success: saveResults
        error: (error) ->
          log "Error while saving: #{JSON.stringify error}"
        plugin:
          name: "ReadSms"
          function: "GetTexts"
          args: ["",-1]

    getAllSmsAfterCutoffSaveInDB = (cutoff) ->
      cordova.execute
        success: saveResults
        error: (error) ->
          log "Error while saving: #{JSON.stringify error}"
        plugin:
          name: "ReadSms"
          function: "GetTextsAfter"
          args: ["", cutoff, -1]

    error = (error) ->
      log "Error: #{JSON.stringify error}"


    log "setting up DB"
    db = new PouchDB(Pomegranate.config.database_name)

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
        log JSON.stringify error if error?
        log JSON.stringify response if response?
        if response.rows.length is 0
          cuttoffDate = moment().subtract('days', Pomegranate.config.number_of_past_days_to_store_in_db).valueOf()
          log "No SMSs in DB, loading SMSs from past #{Pomegranate.config.number_of_past_days_to_store_in_db} day(s): #{cuttoffDate}."
          #getAllSmsSaveInDB cuttoffDate
          getAllSmsAfterCutoffSaveInDB cuttoffDate
        else
          log "Getting messages after #{response.rows[0].doc.time_received} and adding them to DB"
          getAllSmsAfterCutoffSaveInDB(response.rows[0].doc.time_received)

    db.info (database_info) ->
      db.changes
        continuous: true
        include_docs: true
        filter: (doc) ->
          doc.to and doc.message and not doc.processed
        onChange: (doc) ->
          log "SMS to send: #{JSON.stringify doc}"

          cordova.exec( null, null,
            'SmsPlugin',
            "SendSMS",
            [doc.to, doc.message])

          return
          cordova.execute
            success: ->
              log "SMS sent: #{JSON.stringify doc}"
              doc.processed = true
              db.put doc
            error: (error) ->
              log "Error on sending SMS: #{JSON.stringify doc}, error: #{JSON.stringify error}"
            plugin:
              name: "SmsPlugin"
              function: "SendSMS"
              args: [doc.to, doc.message]
      db.changes
        continuous: true
        include_docs: true
        filter: (doc) ->
          return doc.time_received and not doc.processed
        onChange: (doc) ->
          # TODO this is where we can run some user defined triggers to post to google spreadsheet, send acknowledgements, etc
          log "SMS received but not processed: #{JSON.stringify doc}"
          doc.processed = true
          db.put doc

    $("#send").click ->
      doc.to = $("#to")
      doc.message = $("#message")
      doc.time_created = Date.now()
      doc._id = "#{doc.time_received}+#{text.to}"
      db.put doc # should trigger changes callback

    log "Beginning replication"

    PouchDB.replicate Pomegranate.config.database_name, Pomegranate.config.remote_url,
      continuous: true

    PouchDB.replicate Pomegranate.config.remote_url, Pomegranate.config.database_name,
      continuous: true
      onChange: (change) ->
        log "Replication from cloud caused a change: #{JSON.stringify change}"
