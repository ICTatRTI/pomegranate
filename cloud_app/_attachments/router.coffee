class Router extends Backbone.Router

  initialize: ->
    @menuItems = "send,sent,received,configure,selectProject".split(/,/)
    @sendView = new SendView
    @receivedView = new ReceivedView
    @sentView = new SentView
    @configureView = new ConfigureView
    @selectProjectView = new SelectProjectView

  routes:
    ":project/:action" : "action"
    ":project" : "action"
    ""      : "action"

  updateProject: (project) ->
    if @project?
      $.couch.db(@project).changes().stop()

    @project = project

    $.couch.db(@project).changes().onChange =>
      @sendView.render()
      @receivedView.render()

    $("#menu").html "
      #{
        (for item in @menuItems
          "<a role='button' href='##{@project}/#{item}'>#{item}</a>"
        ).join("")
      }
    "

    @navigate "#{@project}", true

  action: (project,action) ->
    console.log project
    console.log action
    if project? and not @project?
      @updateProject(project)
    action = 'selectProject' unless project
    action = 'send' unless action
    console.log action
    this["#{action}View"].project = project
    this["#{action}View"].render()
    $("##{item}").hide() for item in @menuItems
    $("##{action}").show()

class Person extends Backbone.Model
  url: "person"

class People extends Backbone.Collection

  url: "person"
  model: Person

class Group extends Backbone.Model
  url: "group"

class Groups extends Backbone.Collection
  url: "group"
  model: Group


class GroupManager extends Backbone.View

  el : "#group-manager"

  htmlAddNumbers : "<button class='add-to-numbers'>Add selected group to recipients</button>"
  htmlAddPerson  : "<button class='add-person'>Add Person</button>"
  htmlAddGroup   : "<button class='add-group'>Add Group</button>"


  events:
    "click #group-selector li" : "onGroupClick"
    "click .group-edit" : "onGroupEdit"
    "click .group-remove" : "onGroupRemove"

    "click .add-group" : "addGroup"
    "click .add-person" : "addPerson"

    "change .group-name"  : "onGroupNameChange"
    "blur   .group-name"  : "onGroupNameBlur"

    "change .person-name"  : "onPersonChange"
    "change .person-phone" : "onPersonChange"
    "change .person-tags"  : "onPersonChange"

    "click .person-remove" : "onPersonRemove"

    "click .add-to-numbers" : "addToField"

  onPersonRemove: (event) =>
    $target = $(event.target)
    personId = $target.parents("li").attr('id')

    if window.confirm("are you sure you want to remove this person?") 
      person = @allPeople.get personId
      @allPeople.remove personId
      person.destroy
        success: =>
          @updatePeople()


  onPersonChange: (event) ->
    $target = $(event.target)
    $person = $target.parents("li")

    personId = $person.attr('id')
    person = @allPeople.get(personId)
    person.save
      name        : $person.find(".person-name").val()

      district    : $person.find(".person-district").val()
      designation : $person.find(".person-designation").val()
      tags        : $person.find(".person-tags").val()
    ,
      success: ->
        console.log "saved"



  onGroupEdit: (event) =>
    $target = $(event.target)
    groupId = $target.parent("li").attr('id')
    @editGroup @allGroups.get(groupId)


  onGroupRemove: (event) =>
    $target = $(event.target)
    groupId = $target.parent("li").attr('id')
    if window.confirm("are you sure you want to remove this group?") 
      group = @allGroups.get groupId
      @allGroups.remove groupId
      group.destroy
        success: =>
          @updateGroups()
          @updatePeople()

  onGroupNameBlur: (event) ->
    $target = $(event.target)
    value = $target.val()
    groupId = $target.parent("li").attr('id')
    group = @allGroups.get(groupId)
    @updateGroup(group)


  onGroupNameChange: (event) ->
    $target = $(event.target)
    value = $target.val()
    groupId = $target.parent("li").attr('id')
    group = @allGroups.get(groupId)
    group.save
      "name" : value
    ,
      success: =>
        @updateGroup(group)


  onGroupClick : (event) ->
    $target = $(event.target)
    groupId = $target.attr('id')
    @selected.group = @allGroups.get(groupId)
    @showSelected()

    @$el.find("#people-label").html "People in \"#{@selected.group.escape('name')}\""
    @updatePeople()

  showSelected: ->
    @$el.find("#group-selector li").removeClass("selected")
    @$el.find("##{@selected.group.id}").addClass("selected")


  addPerson: ->
    person = new Person
    person.save 
      "groupId" : @selected.group.id
    ,
      success: =>
        @allPeople.add person
        @updatePeople()

  addGroup: ->
    group = new Group
    group.save null,
      success: =>
        @allGroups.add group
        @updateGroups()
        @updatePeople()


  initialize: ->
    @selected = {}

  render: =>

    @$el.html "
      <h2>Group manager</h2>

      #{@htmlAddNumbers}<br>

      <label id='groups-label'>Groups</label><br>
      <ul id='group-selector'></ul>

      <label id='people-label'>People</label><br>
      <ul id='people'></ul>
    "

    @allGroups = new Groups
    @allGroups.fetch
      success: =>
        @selected.group = @allGroups.first()
        @allPeople = new People
        @allPeople.fetch
          success: =>
            @$el.find("#people-label").html "People in \"#{@selected.group.escape('name')}\""
            @updateGroups()
            @updatePeople()
            @showSelected()

  addToField: ->
    $("#numbers").val (@allPeople.where( "groupId" : @selected.group.id )).map((a)->a.attributes.phone).join("\n")

  updateGroups: =>

    html = ''

    for group in @allGroups.models

      html += "<li id='#{group.id}'>#{@htmlGroup(group)}</li>"

    html += "<li>#{@htmlAddGroup}</li>"

    @$el.find("#group-selector").html html

  editGroup: ( group ) ->
    @$el.find("##{group.id}").html("<input type='text' class='group-name' value='#{group.escape('name')}'></li>").select()

  updateGroup: ( group ) ->
    @$el.find("##{group.id}").html @htmlGroup(group)

  htmlGroup: (group) ->
    return "#{group.get('name')} <span class='group-edit action'>edit</span> <span class='group-remove action'>remove</span>"

  updatePeople: ->
    return @$el.find("#people").html "No group selected" unless @selected.group?
    return @$el.find("#people").html "
      <ul>
        <li>No one in group</li>
        <li>#{@htmlAddPerson}</li>
      </ul>
    " if (people = @allPeople.where( "groupId" : @selected.group.id )).length is 0

    html = ''

    for person in people

      html += "
        <li value='#{person.id}' id='#{person.id}'>
          #{@getPersonTable(person)}
        </li>
      "

    html += "<li>#{@htmlAddPerson}</li>"

    @$el.find("#people").html html


  updatePerson: ( personId ) ->

    @$el.find("##{personId}").html "
        <li value='#{person.id}' id='#{person.id}'>
          #{@getPersonTable(person)}
        </li>
      "

  onNameChange: (event) ->
    $target = $(event.target)
    name = $target.val()
    personId = $target.parent("li")


  getPersonTable: (person) ->
    return "
      <table>
        <tr><th>Name</th>         <td><input type='text' class='person-name'  value='#{person.escape('name')}'></td></tr>
        <tr><th>Phone</th>        <td><input type='text' class='person-phone' value='#{person.escape('phone')}'></td></tr>
        <tr><th>District</th>     <td><input type='text' class='person-district'  value='#{person.escape('district')}'></td></tr>
        <tr><th>Designation</th>  <td><input type='text' class='person-designation'  value='#{person.escape('designation')}'></td></tr>
        <tr><th>Tags</th>         <td><input type='text' class='person-tags'  value='#{person.escape('tags')}'></td></tr>
        <tr><td><button class='person-remove'>remove</button></td></tr>
      </table>
    "


class Message extends Backbone.Model
  url: "message"


class SelectProjectView extends Backbone.View

  el: "#selectProject"

  events:
    "change input#projectName" : "updateProject"

  updateProject: ->
    Pomegranate.router.updateProject($("#projectName").val())

  render: ->
    @$el.html "
      Enter your project name:
      <input id='projectName' type='text'></input>
    "

class ConfigureView extends Backbone.View

  el: "#configure"

  events:
    "click #save_google_form_url" : "save"

  save: ->
    $.couch.db(@project).saveDoc {
      _id: "google_form"
      live_form_url: $("#google_form_url").val()
    }

  render: ->
    @$el.html "
      URL for #{@project} live google form:

      <ol>
        <li>Make your own copy of the <a href='https://docs.google.com/forms/d/12qRAtzhSkRNv6SzSgPPzTmGQm39yzUK5TP-AKcfWvNo/edit?usp=sharing'> Sample SMS Data Form</a>. (Click on 'file', 'make a copy').
        </li>
        <li> Click View live form, once the page opens copy the URL
        </li>
        <li> Paste the URL here, <input id='google_form_url'> and click: <button id='save_google_form_url'>Save google form url</button>
        </li>
      </ol>
    "

class SentView extends Backbone.View

  el: "#sent"

  events:
    "click .send"    : "send"

  render: ->
    columns = "Time, To, Message".split(/,/)

    @$el.html "
      <h2>Sent Messages</h2>
      <table id='sentMessages'>
        <thead>
          <tr>
            #{
              (for header in columns
                "<td>#{header}</td>"
              ).join("")
            }
          </tr>
        </thead>
        <tbody>
        </tbody>
        <tfoot>
          <tr>
            #{
              (for header in columns
                "<td>#{header}</td>"
              ).join("")
            }
          </tr>
        </tfoot>
      </table>
    "
    $.couch.db(@project).allDocs
      include_docs: true
      error: (error) -> console.log JSON.stringify(error)
      success: (results) ->
        for result in results.rows
          if result.doc.to?
            $("table#sentMessages tbody").append "
              <tr>
                <td>#{
                  if result.doc.time_sent
                    moment(parseInt result.doc.time_sent).format("YYYY-MM-DD HH:mm")
                  else
                    "Pending"
                }</td>
                <td>#{result.doc.to}</td>
                <td>#{result.doc.message}</td>
              </tr>

            "
        $("table#sentMessages").dataTable
          aaSorting: [[0,"desc"]]

class ReceivedView extends Backbone.View

  el: "#received"

  events:
    "click .send"    : "send"

  render: =>

    columns = "Time, From, Message".split(/,/)

    @$el.html "
      <h2>Received Messages</h2>
      <table id='receivedMessages'>
        <thead>
          <tr>
            #{
              (for header in columns
                "<td>#{header}</td>"
              ).join("")
            }
          </tr>
        </thead>
        <tbody>
        </tbody>
        <tfoot>
          <tr>
            #{
              (for header in columns
                "<td>#{header}</td>"
              ).join("")
            }
          </tr>
        </tfoot>
      </table>
    "
    $.couch.db(@project).allDocs
      include_docs: true
      error: (error) -> console.log JSON.stringify(error)
      success: (results) =>
        @currentNumberOfResults = results.total_rows
        for result in results.rows
          if result.doc.time_received?
            $("table#receivedMessages tbody").append "
              <tr>
                <td>#{moment(parseInt result.doc.time_received).format("YYYY-MM-DD HH:mm")}</td>
                <td>#{result.doc.from}</td>
                <td>#{result.doc.message}</td>
              </tr>

            "
        $("table#receivedMessages").dataTable
          aaSorting: [[0,"desc"]]


class SendView extends Backbone.View

  el: "#send"

  events:
    "click .send"    : "send"
    "keyup #numbers" : "countNumbers"
    "keyup #text"    : "countCharacters"

    'click .clear-numbers' : "clearNumbers"
    'click .clear-text'    : "clearText"

  clearText :    -> @$el.find("#text").val('');    @countCharacters()
  clearNumbers : -> @$el.find("#numbers").val(''); @countNumbers()

  render: ->
    @$el.html "
    <div>

      <h2>Send</h2>
      <div style='margin-bottom: 2em; width:40%; display:inline-block; vertical-align:top;'>
        <label for='numbers'>Phone numbers</label><br>
        <span id='number-phone-numbers' class='info'></span><br>
        <button class='clear-numbers'>Clear</button><br>
        <textarea id='numbers' style='height:200px'></textarea>
      </div>

      <div style='width:40%;  display:inline-block;vertical-align:top;'>
          <label for='text'>Message</label><br>
          <span id='chars-left' class='info'></span><br>
          <button class='clear-text'>Clear</button><br>
          <textarea id='text'></textarea><br>
          <button class='send'>Send</button>
      </div>

    </div>
    "

    @countCharacters()
    @countNumbers()

  send: ->

    numbers = $("#numbers").val().split(/\n/)

    $("#log").append "Adding #{numbers.length} message(s) to the outgoing message queue<br>"

    for number in numbers
      $.couch.db(@project).saveDoc {
        message: $("#text").val()
        to: number
      }
    
    Pomegranate.router.navigate "#{@project}/sent", true

  countNumbers: ->
    value = $("#numbers").val()
    count = 0
    count = value.split(/([^0-9].)/).length unless value.replace(/\s/g,'').length is 0
    $("#number-phone-numbers").text "#{count} numbers entered"

  countCharacters: ->
    remaining = 160 - $("#text").val().length
    $("#chars-left").text "#{remaining} characters left"

Pomegranate =
  db_name    : window.location.pathname.split("/")[1]
  design_doc : _.last(String(window.location).split("_design/")).split("/")[0]

Pomegranate.router = new Router()

Backbone.couch_connector.config.db_name   = Pomegranate.db_name
Backbone.couch_connector.config.ddoc_name = Pomegranate.design_doc
Backbone.couch_connector.config.global_changes = false

Backbone.history.start()

Pomegranate.debug = (string) ->
  console.log string
  $("#log").append string + "<br/>"
