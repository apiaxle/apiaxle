# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.

_ = require "lodash"
path = require "path"
async = require "async"
express = require "express"
Redis = require "redis"

Redis = require "redis"

{ Js2Xml } = require "js2xml"
{ Application } = require "scarf"
{ NotFoundError } = require "./error"

class exports.AxleApp extends Application
  configureExpress: ( cb ) ->
    # error handler
    @use @express.router
    @disable "x-powered-by"

    # very simple logger if we're at debug log level
    @debugOn = @config.application.debug is true
    if @debugOn
      @logger.warn "Debug mode is switched on"

      @use ( req, res, next ) =>
        @logger.debug "#{ req.method } - #{ req.url }"
        next()

  configure: ( cb ) ->
    @readConfiguration ( err, @config, filename ) =>
      return cb err if err

      @setupLogger @config.logging, ( err, @logger ) =>
        return cb err if err

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
    all.push ( cb ) => @redisConnect "redisClient", cb
    all.push ( cb ) => @loadAndInstansiatePlugins cb

    async.series all, ( err ) =>
      return cb err if err
      return cb null, ( ) => @redisClient.quit()

  redisConnect: ( client_name, cb ) =>
    # grab the redis config
    { port, host, sentinel, auth } = @config.redis
    # are we up for some sentinel fun?
    this[client_name] = null
    if sentinel
      this[client_name] = Redis.createClient
        port: port
        host: host
        logger: { log: -> }

      this[client_name].on "failover-start", => @logger.warn "Failover starts."
      this[client_name].on "failover-end", => @logger.warn "Failover ends."
      this[client_name].on "disconnected", => @logger.warn "Old master disconnected."
    else
      this[client_name] = Redis.createClient port, host, { auth_pass: auth}

    this[client_name].on "error", ( err ) => @logger.warn "#{ err }"
    this[client_name].on "ready", cb

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
            auth:
              type: "string"
              default: ""
        apiNameRegex:
          type: "string"
          default: "^(.+?)\\.api\\."

  getRoutingSchema: ->
    {}=
      type: "object"
      additionalProperties: false
      properties:
        routing:
          type: "object"
          additionalProperties: false
          properties:
            path_to_api:
              type: "object"
              additionalProperties: true

  getHitProcessorsSchema: ->
    {}=
      type: "object"
      additionalProperties: false
      properties:
        hit_processors:
          type: "array"
          items:
            type: "object"
            additionalProperties: false
            properties:
              path:
                type: "string"
              args:
                type: "object"
                additionalProperties: true

  getConfigurationSchema: ->
    _.merge @getAppConfigSchema(),
            @getLoggingConfigSchema(),
            @getApiaxleConfigSchema(),
            @getRoutingSchema(),
            @getHitProcessorsSchema()

  controller: ( name ) ->
    return @plugins.controllers[name]

  model: ( name ) ->
    return @plugins.models[name]

  getErrorFormat: ( req ) ->
    if query = req.parsed_url?.query
      if query and query.format and query.format in [ "xml", "json" ]
        return query.format

    if /application\/xml/.test(req.headers.accept)
      return "xml"

    if req.api?.data.apiFormat is "xml"
      return "xml"

    return "json"

  # because the proxy doesn't use express we can't use nice things
  # like res.json here.
  error: ( err, req, res ) ->
    output =
      error:
        type: err.name
        message: err.message

    output.error.details = err.details if err.details
    output.error.info = req.api.data.errorMessage if req.api && req.api.data && req.api.data.errorMessage

    # add the stacktrace if we're debugging
    if @debugOn
      output.error.stack = err.stack

    status = err.constructor.status or 400

    if @getErrorFormat( req ) is "json"
      meta =
        version: 1
        status_code: status

      res.writeHead status, { "Content-Type": "application/json" }
      return res.end JSON.stringify
        meta: meta
        results: output

    # need xml
    res.writeHead status, { "Content-Type": "application/xml" }
    js2xml = new Js2Xml "error", output.error
    return res.end js2xml.toString()

  # this will come from an express app
  onError: ( err, req, res, next ) ->
    @error err, req, res
