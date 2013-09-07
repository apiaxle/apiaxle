#!/usr/bin/env coffee

# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.

fs = require "fs"
url = require "url"
redis = require "redis"
async = require "async"
http = require "http"
httpProxy = require "http-proxy"

cluster = require "cluster"
cpus = require("os").cpus()

{ AxleApp } = require "apiaxle-base"
{ ApiUnknown, KeyError } = require "./lib/error"

class exports.ApiaxleProxy extends AxleApp
  @plugins = {}

  # we don't use the constructor in scarf because we don't want to use
  # express in this instance.
  constructor: ( options ) ->
    @endpoint_caches = {}
    @setOptions options

  getApiName: ( req, cb ) ->
    if parts = /^(.+?)\.api\./.exec req.headers.host
      return cb null, parts[1]

    return cb new ApiUnknown "No api specified (via subdomain)"

  error: ( err, res ) -> res.end err.message

  getKeyrings: ( cb ) ->
    @key.supportedKeyrings ( err, keyrings ) =>
      return cb err if err
      return cb null, ( @keyrings = keyrings )

  getApi: ( name, cb ) ->
    @model( "apifactory" ).find [ name ], ( err, results ) =>
      return cb err if err

      if not results[name]?
        # no api found
        return cb new ApiUnknown "'#{ req.subdomain }' is not known to us."

      return cb null, ( @api = results[name] )

  getKey: ( req, cb ) ->
    key = ( req.query.apiaxle_key or req.query.api_key )

    # if the key isn't a query param, check a regex SFTODO
    if not key
      key = @getRegexKey req.url, @api.data.extractKeyRegex

    if not key
      return cb new KeyError "No api_key specified."

    return @authenticateWithKey key, req, cb

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

  authenticateWithKey: ( key, req, cb ) ->
    @model( "keyfactory" ).find [ key ], ( err, results ) =>
      return cb err if err

      all = []

      # check the key is for this api
      @api.supportsKey key, ( err, supported ) =>
        return cb err if err

        if supported is false
          return cb new KeyError "'#{ key }' is not a valid key for '#{ req.subdomain }'"

        if results[key]?.data.sharedSecret
          if not providedToken = ( req.query.apiaxle_sig or req.query.api_sig )
            return cb new KeyError "A signature is required for this API."

          all.push ( cb ) =>
            @validateToken providedToken, key, results[key].data.sharedSecret, cb

        async.series all, ( err ) ->
          return cb err if err

          results[key].data.key = key
          return cb null, ( @key = results[key] )

  getHttpProxyOptions: ( api ) ->
    ep = api.data.endPoint
    return @endpoint_caches[ep] if @endpoint_caches[ep]

    [ host, port ] = ep.split ":"

    @endpoint_caches[api.data.endPoint] =
      host: host
      port: ( port or 80 )

    return @endpoint_caches[api.data.endPoint]

  run: ( cb ) ->
    server = httpProxy.createServer ( req, res, proxy ) =>
      @getApiName req, ( err, name ) =>
        return @error err, res if err

        @getApi name, ( err, api ) =>
          return @error err, res if err

          # parse the url to get the keys
          parsed_url = url.parse req.url, true
          req.query = parsed_url.query

          @getKey req, ( err, key ) =>
            return @error err, res if err

            @getKeyrings ( err, keyrings ) =>
              return @error err, res if err
              return proxy.proxyRequest req, res, @getHttpProxyOptions( api )

    server.listen @options.port

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
