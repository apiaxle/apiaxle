#!/usr/bin/env coffee

# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.

_ = require "lodash"
fs = require "fs"
urllib = require "url"
redis = require "redis"
async = require "async"
http = require "http"
httpProxy = require "http-proxy"

cluster = require "cluster"
cpus = require("os").cpus()

{ AxleApp } = require "apiaxle-base"
{ ApiUnknown,
  KeyError,
  ApiDisabled,
  KeyDisabled,
  EndpointMissingError,
  EndpointTimeoutError,
  ConnectionError,
  DNSError } = require "./lib/error"

class exports.ApiaxleProxy extends AxleApp
  @plugins = {}

  @ENDPOINT_ERROR_MAP =
    ETIMEDOUT: ( ) -> new EndpointTimeoutError "API endpoint timed out."
    ENOTFOUND: ( ) -> new EndpointMissingError "API endpoint could not be found."
    EADDRINFO: ( ) -> new DNSError "API endpoint could not be resolved."
    ECONNREFUSED: ( ) -> new ConnectionError "API endpoint could not be reached."

  # we don't use the constructor in scarf because we don't want to use
  # express in this instance.
  constructor: ( options ) ->
    @endpoint_caches = {}
    @setOptions options

  getApiName: ( req, cb ) ->
    if parts = /^(.+?)\.api\./.exec req.headers.host
      return cb null, ( @api_name = parts[1] )

    return cb new ApiUnknown "No api specified (via subdomain)"

  error: ( err, res ) ->
    @rawError err, res, @api

  getKeyringNames: ( key, cb ) ->
    key.supportedKeyrings ( err, keyrings ) =>
      return cb err if err
      return cb null, ( @keyring_names = keyrings )

  getApi: ( name, cb ) ->
    @model( "apifactory" ).find [ name ], ( err, results ) =>
      return cb err if err

      if not results[name]?
        # no api found
        return cb new ApiUnknown "'#{ name }' is not known to us."

      if results[name].isDisabled()
        return cb new ApiDisabled "This API has been disabled."

      return cb null, ( @api = results[name] )

  getKeyName: ( query, url, cb ) ->
    key = ( query.apiaxle_key or query.api_key )

    # if the key isn't a query param, check a regex SFTODO
    if not key
      key = @getRegexKey url, @api.data.extractKeyRegex

    if not key
      return cb new KeyError "No api_key specified."

    return cb null, ( @key_name = key )

  getKey: ( name, cb ) ->
    @model( "keyfactory" ).find [ name ], ( err, results ) =>
      return cb err if err
      return cb null, ( @key = results[name] )

  validateToken: ( providedToken, key, sharedSecret, cb ) ->
    now = Date.now() / 1000

    potentials = [
      now,

      now + 1, now - 1,
      now + 2, now - 2,
      now + 3, now - 3
    ]

    for potential in potentials
      date = Math.floor( potential ).toString()

      hmac = crypto.createHmac "sha1", sharedSecret
      hmac.update date
      hmac.update key

      processed = hmac.digest "hex"

      if processed is providedToken
        return cb null, processed

    # none of the potential matches matched
    return cb new KeyError "Invalid signature (got #{processed})."

  # Attempts to parse regex from url
  getRegexKey: ( url, regex ) ->
    if not regex
      return null

    matches = url.match new RegExp(regex)

    if matches and matches.length > 1
      return matches[1]

    # Default out
    return null

  authenticateWithKey: ( key, api, query, cb ) ->
    all = []

    # check the key is for this api
    api.supportsKey key.id, ( err, supported ) =>
      return cb err if err

      if ( not key ) or ( not supported )
        return cb new KeyError "'#{ key.id }' is not a valid key for '#{ @api.id }'"

      if key.isDisabled()
        return cb new KeyDisabled "This API key has been disabled."

      if key.data.sharedSecret
        if not providedToken = ( query.apiaxle_sig or query.api_sig )
          return cb new KeyError "A signature is required for this API."

        all.push ( cb ) =>
          @validateToken providedToken, key, key.data.sharedSecret, cb

      async.series all, ( err ) =>
        return cb err if err
        return cb null, key

  getHttpProxyOptions: ( api ) ->
    ep = api.data.endPoint
    return @endpoint_caches[ep] if @endpoint_caches[ep]

    [ host, port ] = ep.split ":"

    @endpoint_caches[api.data.endPoint] =
      host: host
      port: ( port or 80 )
      timeout: ( api.data.endPointTimeout * 1000 )

    return @endpoint_caches[api.data.endPoint]

  rebuildRequest: ( req, pathname, query ) ->
    endpointUrl = ""

    # here we support a default path for the request. This makes
    # sense with people like the BBC who have many APIs all sitting
    # on the one domain.
    if ( defaultPath = @api.data.defaultPath )
      endpointUrl += defaultPath

    # the bit of the path that was actually requested
    endpointUrl += pathname

    if not @api.data.sendThroughApiSig
      delete query.apiaxle_sig
      delete query.api_sig

    if not @api.data.sendThroughApiKey
      delete query.apiaxle_key
      delete query.api_key

    if not _.isEmpty query
      endpointUrl += "?"
      newStrings = ( "#{ key }=#{ value }" for key, value of query )
      endpointUrl += newStrings.join( "&" )

    # here's the actual setting
    req.url = endpointUrl

    return req

  run: ( cb ) ->
    server = httpProxy.createServer ( req, res, proxy ) =>
      @getApiName req, ( err, name ) =>
        return @error err, res if err

        @getApi name, ( err, api ) =>
          return @error err, res if err

          # parse the url to get the keys
          { query, pathname, url } = urllib.parse req.url, true

          # TODO: remove the requirement for this
          req.query = query

          queue = []

          # key details
          queue.push ( cb ) => @getKeyName query, url, cb
          queue.push ( cb ) => @getKey @key_name, cb
          queue.push ( cb ) => @authenticateWithKey @key, @api, query, cb

          # we don't need to resolve the keyrings to their full
          # objects at the moment.
          queue.push ( cb ) => @getKeyringNames @key, cb

          async.series queue, ( err ) =>
            return @error err, res if err

            req = @rebuildRequest req, pathname, query
            return proxy.proxyRequest req, res, @getHttpProxyOptions( api )

    server.proxy.on "proxyError", @handleProxyError
    server.listen @options.port, cb

  handleProxyError: ( err, req, res ) =>
    statsModel = @model "stats"

    # if we know how to handle an error then we also log it
    if err_func = @constructor.ENDPOINT_ERROR_MAP[ err.code ]
      new_err = err_func()

      return statsModel.hit @api.id, @key.id, @keyring_names, "error", new_err.name, ( err ) =>
        return @error new_err, res, @api

    # if we're here its a new kind of error, don't want to call
    # statsModel.hit without knowing what it is for now
    @logger.warn "Error won't be statistically logged: '#{ err.message }'"
    error = new Error "Unrecognised error: '#{ err.message }'."

    return @error error, res, @api

if not module.parent
  optimism = require( "optimist" ).options
    p:
      alias: "port"
      default: 3000
      describe: "Port to bind the proxy to."
    h:
      alias: "host"
      default: "127.0.0.1"
      describe: "Host to bind the proxy to."
    f:
      alias: "fork-count"
      default: cpus.length
      describe: "How many internal processes to fork"

  optimism.boolean "help"
  optimism.describe "help", "Show this help screen"

  if optimism.argv.help or optimism.argv._.length > 0
    optimism.showHelp()
    process.exit 0

  # taking a port from the commandline makes it much easier to cluster
  # the app
  { port, host } = optimism.argv

  if cluster.isMaster
    # fork for each CPU or the specified amount
    cluster.fork() for i in [ 1..optimism.argv["fork-count"] ]

    cluster.on "exit", ( worker, code, signal ) ->
      console.log( "Worker #{ worker.process.pid } died." )
  else
    api = new exports.ApiaxleProxy
      name: "apiaxle"
      port: port
      host: host

    all = []

    all.push ( cb ) -> api.configure cb
    all.push ( cb ) -> api.loadAndInstansiatePlugins cb
    all.push ( cb ) -> api.redisConnect cb
    all.push ( cb ) -> api.run cb

    async.series all, ( err ) ->
      throw err if err
