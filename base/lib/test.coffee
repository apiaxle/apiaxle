# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
fs     = require "fs"
dns    = require "dns"
http   = require "http"
path   = require "path"
sinon  = require "sinon"
async  = require "async"
libxml = require "libxmljs"
_      = require "lodash"

{ Application } = require "./application"
{ TwerpTest }   = require "twerp"
{ Redis }       = require "../app/model/redis"

# merges itself into Date
require "date-utils"

# GET, POST, PUT, HEAD etc.
{ httpHelpers } = require "./mixins/http-helpers"

# use the extend paradigm without actually using the Module class
extend = ( obj, mixin ) ->
  obj[ name ] = method for name, method of mixin
  return obj

include = ( klass, mixin ) ->
  return extend klass.prototype, mixin

class Clock
  constructor: ( @sinonClock ) ->

  tick: ( time ) ->
    @sinonClock.tick time

  set: ( to_ms ) ->
    current = Date.now()

    if to_ms > current
      @tick to_ms - current
    else
      @tick current - to_ms

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

# note this is extended with httpHelpers
app_mem = null
class exports.AppTest extends TwerpTest
  @port = 26100

  constructor: ( options ) ->
    all = []

    if not @app = app_mem
      @app = app_mem = new @constructor.appClass
        env: "test"
        port: @constructor.port

    @host_name = "http://127.0.0.1:#{ @constructor.port }"

    @stubs = []
    @spies  = []

    # fixture lists, persist over lifetime
    @fixtures = new Fixtures @app

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

  getClock: ( seed=Date.now() ) ->
    new Clock @sandbox.useFakeTimers seed

  startWebserver: ( done ) ->
    @app.run done

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

  configureApp: ( cb ) ->
    all = []

    all.push ( cb ) => @app.configure cb
    all.push ( cb ) => @app.redisConnect "redisClient", cb
    all.push ( cb ) => @app.loadAndInstansiatePlugins cb
    all.push ( cb ) => @app.initErrorHandler cb

    async.series all, ( err ) ->
      console.log( err ) if err

      cb()

  start: ( done ) ->
    all = []

    all.push ( cb ) => @configureApp cb

    if @constructor.start_webserver
      all.push ( cb ) =>
        @startWebserver cb

    async.series all, ( err ) ->
      console.log( err ) if err
      done()

  finish: ( done ) ->
    # this is synchronous
    if @constructor.start_webserver
      @app.close()

    @app.redisClient.quit()

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

include exports.AppTest, httpHelpers

class Fixtures
  constructor: ( @app ) ->

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

  createKeyring: ( name, options, cb ) =>
    @app.model( "keyringfactory" ).create name, options, cb

  createKey: ( name, options, cb ) =>
    @app.model( "keyfactory" ).create name, options, cb

  createApi: ( name, options, cb ) =>
    @app.model( "apifactory" ).create name, options, cb
