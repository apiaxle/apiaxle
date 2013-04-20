_ = require "lodash"
path = require "path"
async = require "async"
express = require "express"
redis = require "redis"

{ Application } = require "scarf"

class exports.AxleApp extends Application
  configure: ( cb ) ->
    @readConfiguration ( err, @config, filename ) =>
      return cb err if err

      @debugOn = @config.application.debug is true

      @setupLogger @config.logging, ( err, @logger ) =>
        return cb err if err

        # very simple logger if we're at debug log level
        if @debugOn
          @logger.warn "Debug mode is switched on"

          @use ( req, res, next ) =>
            @logger.debug "#{ req.method } - #{ req.url }"
            next()

        @logger.info "Loaded configuration from #{ filename }"
        return cb null

  redisConnect: ( cb ) =>
    # grab the redis config
    { port, host } = @config.redis

    @redisClient = redis.createClient( port, host )
    @redisClient.on "error", ( err ) -> throw new RedisError err
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

  run: ( cb ) ->
    @configure ( err ) =>
      return cb err if err

      { port, host } = @config.application
      @logger.info "Staring to listen at #{ host }:#{ port }"
      @express.listen port, host, cb

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

  controllers: ( name ) ->
    return @plugins.controllers[name]

  model: ( name ) ->
    return @plugins.models[name]

if not module.parent
  dash = new Dash()
  dash.run ( err ) -> throw err if err
