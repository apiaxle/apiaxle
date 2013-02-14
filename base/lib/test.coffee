fs     = require "fs"
dns    = require "dns"
http   = require "http"
path   = require "path"
sinon  = require "sinon"
async  = require "async"
libxml = require "libxmljs"
_      = require "underscore"

{ Application } = require "./application"
{ TwerpTest }   = require "twerp"
{ Redis }       = require "../app/model/redis"

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

  addSeconds: ( number ) ->
    @_addTime "addSeconds", number

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
    try
      output = libxml.parseXmlString @data
    catch err
      return callback err, null

    return callback null, output

  parseJson: ( callback ) ->
    try
      output = JSON.parse @data, "utf8"
    catch err
      return callback err, null

    return callback null, output

application_mem = null
application_fixtures = null

class exports.AppTest extends TwerpTest
  @port = 26100

  constructor: ( options ) ->
    # avoid re-reading configuration and stuff
    @app = if application_mem
      application_mem
    else
      application_mem = new @constructor.appClass().configureModels()
                                                   .configureControllers()

    @stubs = []
    @spies  = []

    # fixture lists, persist over lifetime
    @fixtures = if application_fixtures
      application_fixtures
    else
      application_fixtures = new Fixtures @app

    super options

  stubDns: ( mapping ) ->
    # we need to avoid hitting twitter.api.localhost because it won't
    # exist on everyone's machine
    old = dns.lookup

    @getStub dns, "lookup", ( domain, cb ) ->
      for name, address of mapping
        if domain is name
          return cb null, address, 4

      return old domain, cb

  getClock: ( seed=new Date().getTime() ) ->
    new Clock @sandbox.useFakeTimers( seed )

  startWebserver: ( done ) ->
    @app.run "127.0.0.1", @constructor.port, done

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

    @app.logger.debug "Making a #{ options.method} to #{ options.path }"
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
    chain = []

    @runRedisCommands = []

    if @constructor.start_webserver
      chain.push ( cb ) =>
        @startWebserver cb

    chain.push @app.redisConnect

    wrapCommand = ( access, model, command, fullkey ) ->
      access: access
      model: model
      command: command
      key: fullkey

    # capture each redis event as it happens so that we can see what
    # we've been running
    for name, model of @app.models
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
    @app.app.close( ) if @constructor.start_webserver
    @app.redisClient.quit( )

    # remove the redis emitters
    for name, model of @app.models
      do( name, model ) =>
        model.ee.removeAllListeners "read"
        model.ee.removeAllListeners "write"

    super done

  "teardown restore stubs": ( done ) ->
    # get rid of the old sandbox
    @sandbox.restore()
    @sandbox = null

    done( )

  flushAllKeys: ( cb ) ->
    base_object = new Redis @app

    @app.redisClient.keys [ "#{ base_object.base_key }*" ], ( err, keys ) =>
      multi = @app.redisClient.multi()

    @app.redisClient.keys [ "#{ base_object.base_key }*" ], ( err, keys ) =>
      multi = @app.redisClient.multi()

      for key in keys
        multi.del key, ( err ) ->
          return cb err if err

      multi.exec cb

  "setup": ( done ) ->
    tasks = []

    # sanbox for sinon
    @sandbox = sinon.sandbox.create()

    @runRedisCommands = []

    # flush the database first
    if @constructor.empty_db_on_setup
      @flushAllKeys done
    else
      done()

  fakeIncomingMessage: ( status, data, headers, callback ) ->
    res = new http.IncomingMessage( )

    res.headers = headers
    res.statusCode = status

    callback null, res

    res.emit "data", data
    res.emit "end"

class Fixtures
  constructor: ( @app ) ->
    @api_names  = require "../test/fixtures/api-fixture-names.json"
    @bucket_ids = require "../test/fixtures/key-bucket-fixture-names.json"
    @keys       = [ 1..1000 ]

  create: ( data, cb ) ->
    all = [ ]

    # add any new convenience methods here
    type_map =
      api: @createApi
      key: @createKey
      keyring: @createKeyring

    # loop over the structure grabbing the names and details
    for type, item of data
      if not type in _.keys type_map
        return cb new Error "Don't know how to handle #{ type }"

      for name, details of item
        do( type, name, details ) =>
          all.push ( cb ) =>
            type_map[ type ]( name, details, cb )

    async.series all, cb

  createKeyring: ( args..., cb ) =>
    name    = null
    options = { }

    # grab the optional args and make sure a name is assigned
    switch args.length
      when 2 then [ name, options ] = args
      when 1 then [ name ] = args
      else name = "bucket-#{ @keys.pop() }"

    @app.model( "keyringFactory" ).create "#{ name }", options, cb

  createKey: ( args..., cb ) =>
    name = null

    passed_options  = { }
    default_options =
      forApis: [ "twitter" ]

    # grab the optional args and make sure a name is assigned
    switch args.length
      when 2 then [ name, passed_options ] = args
      when 1 then [ name ] = args
      else name = @keys.pop()

    # merge the options
    options = _.extend default_options, passed_options

    @app.model( "keyFactory" ).create "#{ name }", options, cb

  createApi: ( args..., cb ) =>
    name = null

    passed_options  = { }
    default_options =
      endPoint: "api.twitter.com"
      apiFormat: "json"

    # grab the optional args and make sure a name is assigned
    switch args.length
      when 2 then [ name, passed_options ] = args
      when 1 then [ name ] = args
      else name = @api_names.pop()

    # merge the options
    options = _.extend default_options, passed_options

    @app.model( "apiFactory" ).create name, options, cb
