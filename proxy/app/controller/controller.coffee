# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
crypto = require "crypto"
async  = require "async"

{ Controller } = require "scarf"

{ ValidationError } = require "apiaxle-base"
{ ApiUnknown, KeyError } = require "../../lib/error"

class exports.ApiaxleController extends Controller
  simpleBodyParser: ( req, res, next ) ->
    req.body = ""

    # add a body for PUTs and POSTs
    return next() if req.method in [ "HEAD", "GET" ]

    req.on "data", ( c ) -> req.body += c
    req.on "end", next

  keyrings: ( req, res, next ) ->
    req.key.supportedKeyrings ( err, keyrings ) ->
      return next err if err

      req.keyrings = keyrings
      return next()

  subdomain: ( req, res, next ) ->
    # if we're called from a subdomain then let req know
    if parts = /^(.+?)\.api\./.exec req.headers.host
      req.subdomain = parts[1]
      return next()

    return next new ApiUnknown "No api specified (via subdomain)"

  api: ( req, res, next ) =>
    @app.model( "apifactory" ).find [ req.subdomain ], ( err, results ) ->
      return next err if err

      if not results[req.subdomain]?
        # no api found
        return next new ApiUnknown "'#{ req.subdomain }' is not known to us."

      req.api = results[req.subdomain]
      return next()

  authenticateWithKey: ( key, req, next ) ->
    @app.model( "keyfactory" ).find [ key ], ( err, results ) =>
      return next err if err

      all = []

      # check the key is for this api
      req.api.supportsKey key, ( err, supported ) =>
        return next err if err

        if supported is false
          return next new KeyError "'#{ key }' is not a valid key for '#{ req.subdomain }'"

        if results[key]?.data.sharedSecret
          if not providedToken = ( req.query.apiaxle_sig or req.query.api_sig )
            return next new KeyError "A signature is required for this API."

          all.push ( cb ) =>
            @validateToken providedToken, key, results[key].data.sharedSecret, cb

        async.series all, ( err ) ->
          return next err if err

          results[key].data.key = key
          req.key = results[key]

          return next()

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

  key: ( req, res, next ) =>
    key = ( req.query.apiaxle_key or req.query.api_key )

    # if the key isn't a query param, check a regex
    if not key
      key = @getRegexKey req.url, req.api.data.extractKeyRegex

    if not key
      return next new KeyError "No api_key specified."

    @authenticateWithKey( key, req, next )
