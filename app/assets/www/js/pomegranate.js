// Generated by CoffeeScript 1.6.2
(function() {
  $(function() {
    return $(document).on("deviceready", function() {
      var db, error, getAllSmsAfterCutoffSaveInDB, getAllSmsSaveInDB, saveResults, smsByTimeReceived, smsReceivedButNotProcessed, smsToSend;

      cordova.execute = function(options) {
        return cordova.exec(options.success, options.error, options.plugin.name, options.plugin["function"], options.plugin.args);
      };
      db = new PouchDB("Pomegranate");
      smsByTimeReceived = function(doc) {
        if (doc.time_received) {
          return emit(doc.time_received, null);
        }
      };
      smsReceivedButNotProcessed = function(doc) {
        if (doc.time_received && !doc.processed) {
          return emit(doc.time_received, null);
        }
      };
      smsToSend = function(doc) {
        if (doc.time_created && !doc.processed) {
          return emit(doc.time_created, null);
        }
      };
      saveResults = function(results) {
        return _(results.texts).each(function(text) {
          text._id = "" + text.time_received + "+" + text.from;
          return db.put(text);
        });
      };
      getAllSmsSaveInDB = function() {
        return cordova.execute({
          success: saveResults,
          error: function(error) {
            return console.log("Error while saving: " + (JSON.stringify(error)));
          },
          plugin: {
            name: "ReadSms",
            "function": "GetTexts",
            args: ["", -1]
          }
        });
      };
      getAllSmsAfterCutoffSaveInDB = function(cutoff) {
        return cordova.execute({
          success: saveResults,
          error: function(error) {
            return console.log("Error while saving: " + (JSON.stringify(error)));
          },
          plugin: {
            name: "ReadSms",
            "function": "GetTextsAfter",
            args: ["", cutoff, -1]
          }
        });
      };
      error = function(error) {
        return console.log("Error: " + (JSON.stringify(error)));
      };
      db.query({
        map: smsByTimeReceived
      }, {
        reduce: false,
        limit: 1,
        include_docs: true,
        descending: true
      }, function(error, response) {
        if (response.rows.length === 0) {
          console.log("No SMS's in DB, loading all SMSs on phone");
          return getAllSmsSaveInDB();
        } else {
          console.log("Getting messages after " + response.rows[0].time_received + " and adding them to DB");
          return getAllSmsAfterCutoffSaveInDB(response.rows[0].time_received);
        }
      });
      db.changes({
        continuous: true,
        include_docs: true,
        filter: smsToSend,
        onChange: function(doc) {
          console.log("Change: " + doc);
          return cordova.execute({
            success: function() {
              console.log("SMS sent: " + (JSON.stringify(doc)));
              doc.processed = true;
              return db.put(doc);
            },
            error: function(error) {
              return console.log("Error on sending SMS: " + (JSON.stringify(doc)) + ", error: " + (JSON.stringify(error)));
            },
            plugin: {
              name: "SmsPlugin",
              "function": "SendSMS",
              args: [doc.to, doc.message]
            }
          });
        }
      });
      $("#send").click(function() {
        doc.to = $("#to");
        doc.message = $("#message");
        doc.time_created = Date.now();
        doc._id = "" + doc.time_received + "+" + text.to;
        return db.put(doc);
      });
      PouchDB.replicate('pomegranate', 'http://mikeymckay.iriscouch.com/pomegranate', {
        continuous: true
      });
      return PouchDB.replicate('http://mikeymckay.iriscouch.com/pomegranate', 'pomegranate', {
        continuous: true
      });
    });
  });

}).call(this);
