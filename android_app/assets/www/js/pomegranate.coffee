#
# Utilities
#

U =
  log : ( message, details ) ->
    U.output message, details, "log-info"

  error : ( message, details ) ->
    U.output message, details, "log-error"

  output : ( message, details, cssClass ) ->
    time = moment().format("D-MMM h:mm:ss")
    random = Math.random().toString(36).substr(2)
    console.log message
    details = "<div class='log-details'>#{details}</div>" if details?
    $("#log").append "<div class='#{cssClass}'>#{time} #{message}<span id='log-status-#{random}'></span>#{details||""}<div>"

  exec : ( options ) ->
    cordova.exec options.success, options.error, options.plugin.name, options.plugin.function, options.plugin.args


  status : ( id, status, name) ->
    $status = $("#status-#{id}")
    unless $status.length is 0
      $("#status-#{id}").html(status)
      return
    name = id unless name?
    $("#status").html("<div><b>#{name}</b>: <span id='status-#{status}'>#{status}</span></div>")

#
# Database operations
#

_db = # gets added to pouchDb object
  replicateBothWays : () ->
    U.log "Connecting to cloud"
    PouchDB.replicate P.config.database_name, P.config.remote_url, continuous: true
    PouchDB.replicate P.config.remote_url, P.config.database_name, continuous: true

  saveResults : (results) ->
    if results.msgs.length isnt 0
      _(results.msgs).each (msg) ->
        newDoc = msg
        # Make this deterministic to allow for syncing after deleting the database locally (and syncing with cloud)
        newDoc._id = "#{msg.time_received}+#{msg.from}"
        P.db.put msg, (error, response) ->
          U.error("Error while saving", JSON.stringify error) if error and error.status isnt 409
          if response? and not response.error
            U.log "New message saved", msg.message

  saveAllSms : ->
    U.exec
      success: _db.saveResults
      error: (error) ->
        U.error "Error while saving", JSON.stringify error
      plugin:
        name: "ReadSms"
        function: "GetTexts"
        args: ["",-1]

  saveAllSmsAfter : (cutoff) ->
    U.exec
      success: _db.saveResults
      error: (error) ->
        U.error "Error while saving", JSON.stringify error
      plugin:
        name: "ReadSms"
        function: "GetTextsAfter"
        args: ["", cutoff, -1]



P = {}

#
# Views
#

P.views =
  msgsSent : (doc) ->
    emit(doc._id, null) if doc.to and doc.processed

  msgsRecieved : (doc) ->
    emit(doc._id, null) if doc.time_received and doc.processed

  msgsUnprocessed: (doc) ->
    isUnprocessed = not doc.processed
    isMessage = doc.message
    emit(doc._id, null) if isMessage and isUnprocessed


  msgsByTimeReceived : (doc) ->
    emit(doc.time_received, null) if doc.time_received

  msgsToSend: (doc) ->
    needsToGo = doc.to and not doc.processed
    isMessage = doc.message
    emit(doc._id, null) if isMessage and needsToGo


#
# Filters
#

P.filters = 

  messageNeedsToGo: (doc) ->
    needsToGo = doc.to and not doc.processed
    isMessage = doc.message
    return isMessage and needsToGo

  msgsUnprocessed: (doc) ->
    wasReceived = doc.time_received
    isUnprocessed = not doc.processed
    return wasReceived and isUnprocessed


#
# Config
#

P.config =
  "database_name"      : "ghana"
  "remote_url"         : "http://192.241.251.189:5984/ghana"
  "sync_previous_days" : 10


#
# Boot, called at deviceready
#

P.boot = ->

  P.sender = cordova.require('cordova/plugin/smssendingplugin')

  P.sender.isSupported (supported) ->
    alert "Error\n\nThis device does not support SMS." unless supported
  , ->
    console.log "Error while checking for SMS support"

  U.log "Starting DB"
  try
    P.db = new PouchDB(P.config.database_name, adapter: "websql")
    U.log "Using WebSQL adapter"
  catch e
    U.error "WebSQL database failed", e 

    try
      P.db = new PouchDB(P.config.database_name, adapter: "idb")
      U.log "Using IDB adapter"
    catch e
      U.error "IDB database failed", e 

      try
        P.db = new PouchDB(P.config.database_name, adapter: "leveldb")
      catch e
        U.error "LevelDB database failed", e 

  $.extend(P.db, _db)

  $ ->
    resize = -> $("#log").height( ($(window).height()-($("#log").position().top+($(window).height()*0.2))) + "px" )
    touchScroll('log')
    $(window).on "resize", resize
    resize()
    U.log "Starting application"
    P.startApp()


#
# Start the application
#

P.startApp = ->


  #
  # DB events
  #

  # Check the db for the most recent messages
  # Then add any new ones on the phone to it
  checkMsgs = (callback) ->

    # Update status
    P.db.query { map: P.views.msgsSent }, { reduce: false }
    , ( error, response ) -> U.status("sent", response.rows.length)

    P.db.query { map: P.views.msgsRecieved }, { reduce: false }
    , ( error, response ) -> U.status("received", response.rows.length)

    P.db.query { map: P.views.msgsUnprocessed }, { reduce: false }
    , ( error, response ) -> U.status("processing", response.rows.length)

    P.db.query { map: P.views.msgsByTimeReceived }, { reduce: false }
    , ( error, response ) -> U.status("db", response.rows.length)


    # check for new messages
    P.db.query { map: P.views.msgsByTimeReceived }
    , {
      reduce       : false
      include_docs : true
      limit        : 1
      descending   : true
    }
    , ( error, response ) ->

      U.error("Error querying database", JSON.stringify error) if error?

      if response.rows.length is 0 or not response.rows[0]?.doc?.time_received?

        cutoffTime = moment().subtract('days', P.config.sync_previous_days)

        P.db.saveAllSmsAfter cutoffTime.valueOf()

      else

        time = moment(parseInt(response.rows[0].doc.time_received)).format("d-MMM hh:mm")

        P.db.saveAllSmsAfter(response.rows[0].doc.time_received)



  # all the other checks
  window.checkAgainInterval = setInterval checkMsgs, 10 * 1000
  checkMsgs()

  # Handle messages that need sending
  P.db.changes
    continuous   : true
    include_docs : true
    filter       : P.filters.messageNeedsToGo
    onChange: (change) ->
      doc = change.doc
      doc.time_sent = (new Date()).getTime()
      U.log "Message to send", JSON.stringify _(doc).without

      P.sender.send
        to        : doc.to
        message   : doc.message
        success: ->
          U.log "Message sent", JSON.stringify doc
          doc.processed = true
          P.db.put doc
        error: (error) ->
          U.error "Error sending message: #{JSON.stringify error}", JSON.stringify doc


  # Handle unprocessed received messages
  P.db.changes
    continuous   : true
    include_docs : true
    filter: P.filters.msgsUnprocessed
    onChange: (change) ->
      # TODO this is where we can run some user defined triggers to post to google spreadsheet, send acknowledgements, etc
      U.log "Message processed", JSON.stringify change.doc
      change.doc.processed = true
      P.db.put change.doc


  P.db.replicateBothWays() # ...
  document.addEventListener "online", ( -> U.log('Phone online'); P.db.replicateBothWays()), false
  document.addEventListener "offline",( -> U.log('Phone offline')), false



# one for the money
document.addEventListener "deviceready", P.boot, false
