# extends Date
require "date-utils"

_ = require "underscore"

express      = require "express"
walkTreeSync = require "./walktree"
fs           = require "fs"
redis        = require "redis"

{ Js2Xml }        = require "js2xml"
{ StreamLogger  } = require "../vendor/streamlogger"
{ StdoutLogger  } = require "./stderrlogger"

{ RedisError, NotFoundError } = require "./error"

class exports.Application
  @env = ( process.env.NODE_ENV or "development" )

  constructor: ( ) ->
    app = module.exports = express.createServer()

    @_configure app

  redisConnect: ( cb ) =>
    # grab the redis config
    { port, host } = @config.redis

    @redisClient = redis.createClient( port, host )

    @redisClient.on "error", ( err ) ->
      throw new RedisError err

    @redisClient.on "ready", cb

  script: ( cb ) ->
    @configureModels()

    @redisConnect ( err ) =>
      throw err if err
      cb ( ) => @redisClient.quit()

  run: ( binding_host, port, callback ) ->
    @app.listen port, binding_host, callback

  configureMiddleware: ( ) ->
    return @

  configureControllers: ( ) ->
    @controllers = {}

    return @ unless @constructor.controllersPath

    for [ abs, clean_path ] in @_controllerList()
      try
        classes = require abs

        for cls, func of classes
          ctrlr =  new func @, clean_path

          # this is used by the documentation generator
          @controllers[ cls ] = ctrlr

          @logger.info "Loading controller #{ cls } with path '#{ ctrlr.path() }'"
      catch e
        throw new Error( "Failed to load controller #{abs}: #{e}" )

    return @

  configureModels: ( ) ->
    @.models or= {}

    modelPaths = @_modelList( "#{ __dirname }/../app/model" )

    # add the new models
    if @constructor.modelsPath
      modelPaths = modelPaths.concat( @_modelList( @constructor.modelsPath ) )

    for modelPath in modelPaths
      current = require( modelPath )

      for model, func of current
        # lowercase the first char of the model name
        modelName = model.charAt( 0 ).toLowerCase() + model.slice( 1 )

        if func.instantiateOnStartup
          @logger.info "Loading model '#{model}'"

          # models take an instance of this class as an argument to the
          # constructor. This gives us something like
          # `application.models.metaCache`.
          @.models[ modelName ] = new func @

    return @

  model: ( name ) ->
    @.models[ name ] or null

  controller: ( name ) ->
    @.controllers[ name ] or null

  _modelList: ( initialPath ) ->
    list = []

    walkTreeSync initialPath, null, ( path, filename, stats ) ->
      return unless /\.(coffee|js)$/.exec filename

      list.push "#{ path }/#{ filename }"

    return list

  # grab the list of controllers (which can just be required)
  _controllerList: ( ) ->
    list = []

    walkTreeSync @constructor.controllersPath, null, ( path, filename, stats ) ->
      return unless /_controller\.(coffee|js)$/.exec filename

      abs = "#{ path }/#{ filename }"

      # strip the controllers and .coffee part from the path and pass it
      # in so modules can derive thier views/controller paths.
      clean_path = abs.replace( "./app/controller/", "" )
                      .replace( /_controller\.(coffee|js)/, "" )

      list.push [ abs, clean_path ]

    return list

  _configure: ( app ) ->
    # load up /our/ configuration (from the files in /config)
    @config = require( "./app_config" )( Application.env )

    app.configure ( ) =>
      @configureGeneral app

      app.configure "test",        ( ) => @_configureForTest app
      app.configure "staging",     ( ) => @_configureForStaging app
      app.configure "development", ( ) => @_configureForDevelopment app
      app.configure "production",  ( ) => @_configureForProduction app

      # now let the rest of the class know about app
      @app = app

  configureGeneral: ( app ) ->
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
        type: err.constructor.name
        message: err.message

    if @debug
      output.error.details = err.details if err.details
      output.error.stack = err.stack

    # json
    if req.api?.data.apiFormat isnt "xml"
      meta =
        version: 1
        status_code: err.constructor.status

      return res.json { meta: meta, results: output }, err.constructor.status

    # need xml
    res.contentType "application/xml"
    js2xml = new Js2Xml "error", output.error
    res.send js2xml.toString(), err.constructor.status
