#!/usr/bin/env coffee

# extends Date
_ = require "underscore"

express         = require "express"
walkTreeSync    = require "./lib/walktree"
sys             = require "sys"
fs              = require "fs"
signedCookies   = require "./vendor/signedCookies"

{ StreamLogger  } = require "./vendor/streamlogger"
{ StdoutLogger  } = require "./lib/stderrlogger"
{ Controller    } = require "./app/controller"

{ GatekeeperError, NotFoundError } = require "./lib/error"

class exports.Gatekeeper
  @env = ( process.env.NODE_ENV or "development" )

  constructor: ( ) ->
    app = module.exports = express.createServer( )

    @_configure app

  run: ( binding_host, port, callback ) ->
    @app.listen port, binding_host, callback

  configureMiddleware: ( ) ->

  configureControllers: ( ) ->
    @controllers = [ ]

    for [ abs, clean_path ] in @_controllerList( )
      try
        classes = require abs

        for cls, func of classes
          ctrlr =  new func @, clean_path

          # we do this for the tests
          @controllers[ cls ] or= [ ]
          @controllers[ cls ].push ctrlr

          @logger.info "Loading controller #{ cls } with path '#{ ctrlr.path() }'"

      catch e
        throw new Error( "Failed to load controller #{abs}: #{e}" )

    # catch-all for the error handler (404)
    @app.get '*', ( res, req, next ) ->
      return next new NotFoundError( "Not found." )

    return @

  configureModels: ( ) ->
    @._model or= { }

    for modelPath in @_modelList( )
      current = require( modelPath )

      for model, func of current
        if func.instantiateOnStartup
          @logger.info "Loading model '#{model}'"

          # lowercase the first char of the model name
          modelName = model.charAt( 0 ).toLowerCase() + model.slice( 1 )

          # models take an instance of this class as an argument to the
          # constructor. This gives us something like
          # `gatekeeper.models.metaCache`.
          @._model[ modelName ] = new func @

    return @

  _modelList: ( ) ->
    list = [ ]

    walkTreeSync "./app/model", null, ( path, filename, stats ) ->
      return unless /\.(coffee|js)$/.exec filename

      list.push "#{path}/#{filename}"

    return list

  # grab the list of controllers (which can just be required)
  _controllerList: ( ) ->
    list = [ ]

    walkTreeSync "./app/controller", null, ( path, filename, stats ) ->
      return unless /_controller\.(coffee|js)$/.exec filename

      abs = "#{path}/#{filename}"

      # strip the controllers and .coffee part from the path and pass it
      # in so modules can derive thier views/controller paths.
      clean_path = abs.replace( "./app/controller/", "" )
                      .replace( /_controller\.(coffee|js)/, "" )

      list.push [ abs, clean_path ]

    return list

  _configure: ( app ) ->
    app.configure ( ) =>
      # load up /our/ configuration (from the files in /config)
      @config = require( "./lib/app_config" )( Gatekeeper.env )

      @_configureSessions app
      @_configureGeneral app

      app.enable "jsonp callback"

      app.configure "test",        ( ) => @_configureForTest app
      app.configure "staging",     ( ) => @_configureForStaging app
      app.configure "development", ( ) => @_configureForDevelopment app
      app.configure "production",  ( ) => @_configureForProduction app

      # now let the rest of the class know about app
      @app = app

  _configureSessions: ( app ) ->
    # cookies and sessions
    app.use express.cookieParser( )

    # we need signed cookies for the facebook login flow
    sc = signedCookies.init @config.cookieSecret
    app.use sc.decode()
    app.use sc.encode()

  _configureGeneral: ( app ) ->
    app.use express.bodyParser( )
    app.use express.methodOverride( )
    app.use app.router

    # offload any errors to onError
    app.error ( args... ) => @onError.apply @, args

  _configureForTest: ( app ) ->
    @logger = new StreamLogger "log/test.log"
    @logger.level = @logger.levels.debug
    @debug = true

  _configureForStaging: ( app ) ->
    @logger = new StreamLogger "log/staging-#{port}.log"
    @logger.level = @logger.levels.debug
    @debug = true

  _configureForDevelopment: ( app ) ->
    @logger = new StdoutLogger
    @debug = true

  _configureForProduction: ( app ) ->
    @logger = new StreamLogger "log/production-#{port}.log"
    @logger.level = @logger.levels.info
    @debug = false

  onError: ( err, req, res, next ) ->
    output =
      error:
        status: err.jsonStatus
        message: err.message

    if @debug
      output.error.details = err.details
      output.error.stack = err.stack

    res.json output, err.jsonStatus

if not module.parent
  # taking a port from the commandline makes it much easier to cluster
  # the app
  port = ( process.argv[2] or 3000 )
  host = "127.0.0.1"

  gatekeeper = new exports.Gatekeeper( )

  gatekeeper.run host, port, ( ) ->
    gatekeeper.configureModels()
    gatekeeper.configureControllers()
    gatekeeper.configureMiddleware()
    console.log "Express server listening on port #{port}"
