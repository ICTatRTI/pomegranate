class Router extends Backbone.Router
  routes:
    "login": "login"
    "send": "send"
    "": "default"

  send: ->
    sendView = new SendView()
    sendView.render()

  startApp: ->
    Backbone.history.start()

class SendView extends Backbone.View
  el: "#send"

  render: ->
    @$el.html "
        <h2>Numbers to send text/SMS to <span id='number_phone_numbers'></span></h2>
        <textarea id='numbers' style='height:300px'></textarea>
        <h2>Message to send <span id='chars_left'></span></h2>
        <textarea id='text' style=''></textarea>
        <br/>
        <button>Send</button>
      </div>
    "

  events:
    "click button:contains(Send)" : "send"
    "keyup #numbers": "countNumbers"
    "keyup #text": "countCharacters"

  send: ->
    numbers = $("#numbers").val().split(/\n/)
    $("#log").append "Adding #{numbers.length} message(s) to the outgoing message queue<br/>"
    for number in numbers
      $.couch.db("pomegranate").saveDoc
        message: $("#text").val()
        to: number

  countNumbers: ->
    $("#number_phone_numbers").text "(#{$("#numbers").val().split(/\n/).length} numbers entered)"

  countCharacters: ->
    $("#chars_left").text "(Characters left: #{160 - $("#text").val().length})"

Pomegranate = {}
Pomegranate.router = new Router()
Pomegranate.router.startApp()

Pomegranate.debug = (string) ->
  console.log string
  $("#log").append string + "<br/>"
