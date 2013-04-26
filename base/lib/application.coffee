_ = require "lodash"
path = require "path"
async = require "async"
express = require "express"
redis = require "redis"

{ Js2Xml } = require "js2xml"
{ Application } = require "scarf"

class exports.AxleApp extends Application
  configure: ( cb ) ->
    # error handler
    @use @express.router
    @use ( err, req, res, next ) => @onError err, req, res, next

    @readConfiguration ( err, @config, filename ) =>
      return cb err if err

      @setupLogger @config.logging, ( err, @logger ) =>
        return cb err if err

        # very simple logger if we're at debug log level
        @debugOn = @config.application.debug is true
        if @debugOn
          @logger.warn "Debug mode is switched on"

          @use ( req, res, next ) =>
            @logger.debug "#{ req.method } - #{ req.url }"
            next()

        @logger.info "Loaded configuration from #{ filename }"
        return cb null

  script: ( cb ) ->
    all = []

    all.push ( cb ) => @configure cb
    all.push ( cb ) => @loadAndInstansiatePlugins cb
    all.push ( cb ) => @redisConnect cb

    async.series all, ( err ) =>
      return cb err if err
      return cb null, ( ) => @redisClient.quit()

  redisConnect: ( cb ) =>
    # grab the redis config
    { port, host } = @config.redis

    @redisClient = redis.createClient( port, host )
    @redisClient.on "error", ( err ) -> return cb err
    @redisClient.on "ready", cb

  loadAndInstansiatePlugins: ( cb ) ->
    @plugins = {}

    # add our own models
    @constructor.plugins.models = "#{ __dirname }/../app/model/redis/*.coffee"

    all = []
    for category, path of @constructor.plugins
      do( category, path ) =>
        all.push ( cb ) =>
          @collectPlugins path, ( err, items ) =>
            return cb err if err

            for name, constructor of items
              inst = null

              try
                inst = new constructor this
                friendly_name = if constructor.plugin_name
                  constructor.plugin_name
                else
                  name.toLowerCase()

                @plugins[category] ||= {}
                @plugins[category][friendly_name] = inst
              catch err
                return cb err

            # nothing loaded
            return cb null, [] if not _.keys( @plugins[category] ).length > 0

            list = _.keys( @plugins[category] ).join( ', ' )
            @logger.info "Loaded #{ list } from '#{ path }'"

            return cb null, @plugins

    async.parallel all, ( err ) =>
      return cb err if err
      return cb null, @plugins

  getApiaxleConfigSchema: ->
    {}=
      type: "object"
      additionalProperties: false
      properties:
       redis:
          type: "object"
          additionalProperties: false
          properties:
            port:
              type: "integer"
              default: 3000
            host:
              type: "string"
              default: "localhost"

  getConfigurationSchema: ->
    _.merge @getAppConfigSchema(),
            @getLoggingConfigSchema(),
            @getApiaxleConfigSchema()

  controller: ( name ) ->
    return @plugins.controllers[name]

  model: ( name ) ->
    return @plugins.models[name]

  onError: ( err, req, res, next ) ->
    output =
      error:
        type: err.name
        message: err.message

    output.error.details = err.details if err.details

    # add the stacktrace if we're debugging
    if @debugOn
      output.error.stack = err.stack

    status = err.constructor.status or 400

    # json
    if req.api?.data.apiFormat isnt "xml"
      meta =
        version: 1
        status_code: status

      return res.json status,
        meta: meta
        results: output

    # need xml
    res.contentType "application/xml"
    js2xml = new Js2Xml "error", output.error
    return res.send status, js2xml.toString()
