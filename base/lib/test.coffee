fs     = require "fs"
http   = require "http"
path   = require "path"
sinon  = require "sinon"
async  = require "async"
libxml = require "libxmljs"

{ Application } = require "./application"
{ TwerpTest }   = require "twerp"

class Clock
  constructor: ( @sinonClock ) ->

  tick: ( time ) ->
    @sinonClock.tick time

  _addTime: ( modifier, number=1 ) ->
    now = new Date()
    thenTime = now.getTime()

    # add the time
    now[ modifier ] number

    # move on the fake clock
    @tick ( now.getTime() - thenTime )

  addMinutes: ( number ) ->
    @_addTime "addMinutes", number

  addHours: ( number ) ->
    @_addTime "addHours", number

  addDays: ( number ) ->
    @_addTime "addDays", number

  addMonths: ( number ) ->
    @_addTime "addMonths", number

  addYears: ( number ) ->
    @_addTime "addYears", number

class AppResponse
  constructor: ( @actual_res, @data ) ->
    @statusCode  = @actual_res.statusCode
    @headers     = @actual_res.headers
    @contentType = @headers[ "content-type" ]

  withJquery: ( callback ) ->
    jsdom.env @data, ( errs, win ) =>
      throw new Error errs if errs

      jq = require( "jquery" ).create win

      callback jq

  parseXml: ( callback ) ->
    callback libxml.parseXmlString @data

  parseJson: ( callback ) ->
    output = JSON.parse @data, "utf8"

    callback output

class exports.AppTest extends TwerpTest
  @port = 26100

  constructor: ( options ) ->
    # avoid re-reading configuration and stuff
    @application = if application_mem
      application_mem
    else
      application_mem = new @constructor.appClass().configureModels()
                                                   .configureControllers()

    @stubs = [ ]
    @spies  = [ ]

    super options

  getClock: ( seed=new Date().getTime() ) ->
    new Clock @sandbox.useFakeTimers( seed )

  startWebserver: ( done ) ->
    @application.run "127.0.0.1", @constructor.port, done

  # returns a AppResponse object
  httpRequest: ( options, callback ) ->
    unless @constructor.start_webserver
      throw new Error "Make sure to use @start_webserver for a POST/PUT/DELETE."

    defaults =
      host: "127.0.0.1"
      port: @constructor.port

    # fill in the defaults (though, why port would change, I don't
    # know)
    for key, val of defaults
      options[ key ] = val unless options[ key ]

    req = http.request options, ( res ) =>
      data = ""
      res.setEncoding "utf8"

      res.on "data", ( chunk ) -> data += chunk
      res.on "error", ( err )  -> callback err, null
      res.on "end", ( )        -> callback null, new AppResponse( res, data )

    req.on "error", ( err ) -> callback err, null

    # write the body if we're meant to
    if options.data and options.method not in [ "HEAD", "GET" ]
      req.write options.data

    req.end()

  # stub out `fun_name` of `module` with the function `logic`. The
  # teardown function will deal with restoring all stubs.
  getStub: ( module, fun_name, logic ) ->
    newstub = @sandbox.stub module, fun_name, logic
    return newstub

  # spy on `fun_name` of `module`. The teardown function will deal
  # with restoring all stubs.
  getSpy: ( module, fun_name ) ->
    newspy = @sandbox.spy module, fun_name
    @spies.push newspy
    return newspy

  # returns a AppResponse object
  POST: ( options, callback ) ->
    options.method = "POST"

    @httpRequest options, callback

  # returns a AppResponse object
  GET: ( options, callback ) ->
    options.method = "GET"

    # never GET data
    delete options.data

    @httpRequest options, callback

  # returns a AppResponse object
  PUT: ( options, callback ) ->
    options.method = "PUT"

    @httpRequest options, callback

  # returns a AppResponse object
  DELETE: ( options, callback ) ->
    options.method = "DELETE"

    @httpRequest options, callback

  start: ( done ) ->
    chain = [ ]

    @runRedisCommands = [ ]

    if @constructor.start_webserver
      chain.push ( cb ) =>
        @startWebserver cb

    chain.push @application.redisConnect

    wrapCommand = ( access, model, command, fullkey ) ->
      access: access
      model: model
      command: command
      key: fullkey

    # capture each redis event as it happens so that we can see what
    # we've been running
    for name, model of @application.models
      do( name, model ) =>
        model.ee.on "read", ( command, fullkey ) =>
          @runRedisCommands.push wrapCommand( "read", name, command, fullkey )

        model.ee.on "write", ( command, fullkey ) =>
          @runRedisCommands.push wrapCommand( "write", name, command, fullkey )

    # chain this as it's possible the parent class will implement
    # functionality in `start`
    async.parallel chain, done

  finish: ( done ) ->
    # this is synchronous
    @application.app.close( ) if @constructor.start_webserver
    @application.redisClient.quit( )

    # remove the redis emitters
    for name, model of @application.models
      do( name, model ) =>
        model.ee.removeAllListeners "read"
        model.ee.removeAllListeners "write"

    super done

  "teardown restore stubs": ( done ) ->
    # get rid of the old sandbox
    @sandbox.restore()
    @sandbox = null

    done( )

  "setup": ( done ) ->
    tasks = [ ]

    # sanbox for sinon
    @sandbox = sinon.sandbox.create()

    # flush the database first
    if @constructor.empty_db_on_setup
      for name, model of @application.models
        do ( model ) ->
          tasks.push ( cb ) ->
            model.flush cb

    tasks.push ( cb ) =>
      @runRedisCommands = [ ]
      cb()

    async.series tasks, done

  fakeIncomingMessage: ( status, data, headers, callback ) ->
    res = new http.IncomingMessage( )

    res.headers = headers
    res.statusCode = status

    callback null, res

    res.emit "data", data
    res.emit "end"
