
App.controller 'Controls', ($rootScope, $scope, $window, ace, gh, runner, storage, key, database) ->
  scope = $rootScope.controls = $scope
  #bind run shortcut
  key.bind 'Super-Enter', ->
    scope.run()
    $rootScope.$apply()
  key.bind 'Super-S', ->
    $.notify "Save not supported yet", "warn"
  key.bind 'Ctrl-D', ->
    ace._editor.execCommand("duplicateSelection")

  #use prev mode
  scope.mode = storage.get('mode') or 'javascript'
  ace.config mode:scope.mode
  #click handler
  scope.login = ->
    gh.login()
    return
  #handle auth
  gh.$on 'authenticated', ->
    window.gh = gh

  scope.toggleMode = ->
    if scope.mode is 'javascript'
      scope.mode = 'coffee'
    else
      scope.mode = 'javascript'
    ace.config mode:scope.mode
    storage.set('mode', scope.mode)

  scope.run = ->
    code = ace.get()
    #coffeescript
    if scope.mode is 'coffee'
      try
        code = CoffeeScript.compile code
      catch err
        loc = err.location
        if loc
          ace.highlight {row: loc.first_line, col:loc.first_column}
        $.notify err.toString()
        return
    #confirm js syntax
    try
      acorn.parse code
    catch err
      loc = err.loc
      if err.loc
        ace.highlight {row: loc.line-1, col:loc.column}
      $.notify err.toString()
      return
    #now we run
    runner.run(code)

  rand = ->
    (Math.round(Math.random()*1e9)).toString(16)

  scope.share = (id) ->
    if scope.sharing
      database.off scope.share.id
      ace.onchange = ->
      scope.sharing = false
      window.location.hash = ""
      return
    scope.sharing = true
    generated = false
    if !id
      id = rand()
      generated = true
    scope.share.id = id
    #connect to firebase
    database.init id, (error, dbcode) ->
      if error
        $.notify error, "error"
        return
      #ready
      window.location.hash = id
      if generated
        $.notify "You can now share this page's URL", "success"
      #watch for changes
      recieve = (code) ->
        return if !code or code is ace.get()
        dbcode = code
        ace.set code
        $.notify "Received code update", "success"
      send = (code) ->
        database.set id, code
        $.notify "Updated code share", "success"
      #bind
      database.on id, recieve
      ace.onchange = (code) ->
        return if !code or code is dbcode
        clearTimeout send.t
        send.t = setTimeout send.bind(null, code), 5000
      #if not set, set initial value
      if dbcode
        recieve dbcode
      else
        send ace.get()
      return
  #shared already?
  id = window.location.hash.slice(1)
  if id
    scope.share id
