# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.

_ = require "lodash"
path = require "path"
async = require "async"
express = require "express"
debug = require( "debug" )( "aa:app" )
Redis = require "redis"

RedisSentinel = require "redis-sentinel-client"

{ Js2Xml } = require "js2xml"
{ Application } = require "scarf"
{ NotFoundError } = require "./error"

class exports.AxleApp extends Application
  configure: ( cb ) ->
    # error handler
    @use @express.router
    @disable "x-powered-by"

    @readConfiguration ( err, @config, filename ) =>
      return cb err if err

      debug "Reading configuration"

      @setupLogger @config.logging, ( err, @logger ) =>
        return cb err if err

        debug "Setting up logger"

        # very simple logger if we're at debug log level
        @debugOn = @config.application.debug is true
        if @debugOn
          @logger.warn "Debug mode is switched on"

          @use ( req, res, next ) =>
            @logger.debug "#{ req.method } - #{ req.url }"
            next()

        @logger.info "Loaded configuration from #{ filename }"
        return cb null

  initFourOhFour: ( cb ) ->
    @use ( req, res, next ) ->
      return next new NotFoundError "'#{ req.url }' not found."

    return cb()

  initErrorHandler: ( cb ) ->
    @use ( err, req, res, next ) =>
      return @onError err, req, res, next

    return cb()

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
    { port, host, sentinel } = @config.redis

    # are we up for some sentinel fun?
    @redisClient = null
    if sentinel
      @redisClient = RedisSentinel.createClient
        port: port
        host: host
        logger: { log: -> }

      @redisClient.on "failover-start", => @logger.warn "Failover starts."
      @redisClient.on "failover-end", => @logger.warn "Failover ends."
      @redisClient.on "disconnected", => @logger.warn "Old master disconnected."
    else
      @redisClient = Redis.createClient port, host

    @redisClient.on "error", ( err ) => @logger.warn "#{ err }"
    @redisClient.on "ready", cb

  loadAndInstansiatePlugins: ( cb ) ->
    @plugins = {}

    # add our own models
    @constructor.plugins.models = "#{ __dirname }/../app/model/redis/*.{js,coffee}"

    all = []
    for category, path of @constructor.plugins
      do( category, path ) =>
        all.push ( cb ) =>
          @collectPlugins path, ( err, items ) =>
            return cb err if err

            for name, constructor of items
              inst = null

              try
                debug "Loading plugin #{ name }"

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
            @logger.debug "Loaded #{ list } from '#{ path }'"

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
          additionalProperties: no
          properties:
            sentinel:
              type: "boolean"
              default: false
            port:
              type: "integer"
              default: 6379
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
