#!/usr/bin/env coffee

# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.

_ = require "lodash"
urllib = require "url"
async = require "async"
crypto = require "crypto"
http = require "http"

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

{ PathGlobs } = require "./lib/path_globs"

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
    @hostname_caches = {}
    @endpoint_caches = {}

    @setOptions options
    @path_globs = new PathGlobs()

  _cacheHash: ( url ) ->
    md5 = crypto.createHash "md5"
    md5.update @app.options.env
    md5.update url
    md5.digest "hex"

  _cacheTtl: ( req, cb ) ->
    mustRevalidate = false

    # cache-control might want us to do something. We only care about
    # a few of the pragmas
    if cacheControl = @_parseCacheControl req

      # we might have to revalidate if the client has asked us to
      mustRevalidate = ( not not cacheControl[ "proxy-revalidate" ] )

      # don't cache anything
      if cacheControl[ "no-cache" ]
        return cb null, mustRevalidate, 0

      # explicit ttl
      if ttl = cacheControl[ "s-maxage" ]
        return cb null, mustRevalidate, ttl

    # return the global cache
    return cb null, mustRevalidate, req.api.data.globalCache

  # returns an object which looks like this (with all fields being
  # optional):
  #
  # {
  #   "s-maxage" : <seconds>
  #   "proxy-revalidate" : true|false
  #   "no-cache" : true|false
  # }
  _parseCacheControl: ( req ) ->
    return {} unless req.headers["cache-control"]

    res = {}
    header = req.headers["cache-control"].replace new RegExp( " ", "g" ), ""

    for directive in header.split ","
      [ key, value ] = directive.split "="
      value or= true

      res[ key ] = value

    return res

  getApiName: ( req, res, next ) =>
    { host } = req.headers

    # we have cache hit
    if req.api_name = @hostname_caches[host]
      return next()

    if parts = /^(.+?)\.api\./.exec host
      @hostname_caches[host] = req.api_name = parts[1]
      return next()

    return next new ApiUnknown "No api specified (via subdomain)"

  getKeyringNames: ( req, res, next ) ->
    req.key.supportedKeyrings ( err, names ) ->
      return next err if err

      req.keyring_names = names
      return next()

  getApi: ( req, res, next ) =>
    @model( "apifactory" ).find [ req.api_name ], ( err, results ) =>
      return next err if err

      api = results[req.api_name]

      if not api?
        # no api found
        return next new ApiUnknown "'#{ req.api_name }' is not known to us."

      if api.isDisabled()
        return next new ApiDisabled "This API has been disabled."

      req.api = api
      return next()

  getKeyName: ( req, res, next ) =>
    key = ( req.parsed_url.query.apiaxle_key or req.parsed_url.query.api_key )

    # if the key isn't a query param, check a regex
    if not key
      key = @getRegexKey req.url, req.api.data.extractKeyRegex

    if not key
      return next new KeyError "No api_key specified."

    req.key_name = key
    return next()

  getKey: ( req, res, next ) =>
    @model( "keyfactory" ).find [ req.key_name ], ( err, results ) =>
      return next err if err

      if not results[req.key_name]
        return next new KeyError "'#{ req.key_name }' is not a valid key."

      req.key = results[req.key_name]
      return next()

  validateToken: ( providedToken, key_name, sharedSecret, cb ) ->
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
      hmac.update key_name

      processed = hmac.digest "hex"

      if processed is providedToken
        return cb null, processed

    # none of the potential matches matched
    return cb new KeyError "Invalid signature (got #{processed})."

  # Attempts to parse regex from url
  getRegexKey: ( url, regex ) ->
    matches = url.match new RegExp( regex )

    if matches and matches.length > 1
      return matches[1]

    return null

  authenticateWithKey: ( req, res, next ) =>
    all = []

    # outright disabled
    if req.key.isDisabled()
      return next new KeyDisabled "This API key has been disabled."

    # there's a shared secret, do the token thing
    if req.key.data.sharedSecret
      { apiaxle_sig, api_sig } = req.parsed_url.query

      if not providedToken = ( apiaxle_sig or api_sig )
        return next new KeyError "A signature is required for this API."

      all.push ( cb ) =>
        @validateToken providedToken, req.key_name, req.key.data.sharedSecret, cb

    # check the req.key is for this req.api
    all.push ( cb ) ->
      req.api.supportsKey req.key.id, ( err, supported ) =>
        return cb err if err

        # this API doesn't know about the key
        if not supported
          return cb new KeyError "'#{ req.key.id }' is not a valid req.key for '#{ req.req.api.id }'"

        return cb()

    return async.series all, ( err ) ->
      return next err if err
      return next()

  getHttpProxyOptions: ( req ) ->
    ep = req.api.data.endPoint

    if not @endpoint_caches[ep]
      [ host, port ] = ep.split ":"

      @endpoint_caches[ep] =
        host: host
        port: ( port or 80 )

      @endpoint_caches[ep].timeout = ( req.api.data.endPointTimeout * 1000 )

    options = @endpoint_caches[ep]
    options.path = @buildPath req

    delete req.headers.host
    options.headers = req.headers
    options.method = req.method

    return options

  buildPath: ( req ) =>
    endpointUrl = ""

    # here we support a default path for the request. This makes
    # sense with people like the BBC who have many APIs all sitting
    # on the one domain.
    if ( defaultPath = req.api.data.defaultPath )
      endpointUrl += defaultPath

    endpointUrl += req.parsed_url.pathname

    query = req.parsed_url.query

    if not req.api.data.sendThroughApiSig
      delete query.apiaxle_sig
      delete query.api_sig

    if not req.api.data.sendThroughApiKey
      delete query.apiaxle_key
      delete query.api_key

    if not _.isEmpty query
      endpointUrl += "?"
      newStrings = ( "#{ key }=#{ value }" for key, value of query )
      endpointUrl += newStrings.join( "&" )

    # here's the actual setting
    return endpointUrl

  applyLimits: ( req, res, next ) =>
    args = [
      req.key.id
      req.key.data.qps
      req.key.data.qpd
    ]

    @model( "apilimits" ).apiHit args..., ( err, [ newQps, newQpd ] ) ->
      return next err if err

      # let the user know what they have left
      res.setHeader "X-ApiaxleProxy-Qps-Left", newQps
      res.setHeader "X-ApiaxleProxy-Qpd-Left", newQpd

      return next()

  close: ( cb ) -> @server.close()

  parseUrl: ( req, res, next ) =>
    req.parsed_url = urllib.parse req.url, true
    next();

  setTiming: ( name ) ->
    return ( req, res, next ) ->
      now = Date.now()

      req.timing ||= { first: now }
      req.timing[name] = now - req.timing.first
      next()

  run: ( cb ) ->
    # takes the request, a name and a cb. Used to make a suitable
    # callback replacement that can assign to req[thing_name]
    assReq = ( req, res, name, cb ) =>
      return ( err, result ) =>
        return cb @error( err, req, res ) if err
        return cb null, ( req[name] = result )

    mw = [
      # puts the query params on req
      @setTiming( "start-url-parsed" ),
      @parseUrl,
      @setTiming( "end-url-parsed" ),

      # handle getting the API. If the api is invalid an error will be
      # thrown.
      @setTiming( "start-api-fetched" ),
      @getApiName,
      @getApi,
      @setTiming( "end-api-fetched" ),

      # get the valid key and keyrings. If the key is invalid an error
      # will be thrown.
      @setTiming( "start-key-fetched" ),
      @getKeyName,
      @getKey,
      @setTiming( "end-key-fetched" ),

      @setTiming( "start-key-authenticated" ),
      @authenticateWithKey,
      @setTiming( "end-key-authenticated" ),

      @setTiming( "start-keyrings-fetched" ),
      @getKeyringNames,
      @setTiming( "end-keyrings-fetched" ),

      # make sure the key still has the right to use the api (that
      # limits/quotas haven't been met yet)
      @setTiming( "start-limits-applied" ),
      @applyLimits,
      @setTiming( "end-limits-applied" ),

      @setTiming( "begin-request" )
    ]

    @server = http.createServer ( req, res ) =>
      # run the middleware, this will populate req.api etc
      ittr = ( f, cb ) -> f( req, res, cb )
      async.eachSeries mw, ittr, ( err ) =>
        return @error err, req, res if err

        proxyReq = http.request @getHttpProxyOptions( req )
        proxyReq.on "response", ( proxyRes ) =>
          proxyRes.on "end", =>
            @setTiming( "end-request" )( req, res, -> )

          # copy the response headers
          res.setHeader hdr, val for hdr, val of proxyRes.headers

          proxyRes.pipe res

        proxyReq.on "error", ( err ) => @handleProxyError err, req, res

        return req.pipe proxyReq

    @server.listen @options.port, @options.host, cb

  error: ( err, req, res ) =>
    @setTiming( "end-request" )( req, res, -> )

    req.error = err

    # no status and a new error field
    @model( "queue" ).publish "hit", JSON.stringify
      api_name: req.api_name
      key_name: req.key_name
      keyring_names: req.keyring_names
      timing: req.timing
      parsed_url: req.parsed_url
      error: req.error

    # now for the actual response
    super err, req, res

  handleProxyError: ( err, req, res ) =>
    statsModel = @model "stats"

    # I'm not sure what the right thing to do here is. There could be
    # floods of these from dodgy clients. Perhaps a counter in the
    # future?
    return res.end() if err.code is "ECONNRESET"

    # if we know how to handle an error then we also log it
    error = if err_func = @constructor.ENDPOINT_ERROR_MAP[ err.code ]
      err_func()
    else
      # if we're here its a new kind of error, don't want to call
      # statsModel.hit without knowing what it is for now
      @logger.warn "Error won't be statistically logged: '#{ err.code }, #{ err.message }'"
      new Error "Unrecognised error: '#{ err.message }'."

    return @error error, req, res

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
    all.push ( cb ) -> api.redisConnect "redisClient", cb
    all.push ( cb ) -> api.loadAndInstansiatePlugins cb
    all.push ( cb ) -> api.run cb

    async.series all, ( err ) ->
      throw err if err
