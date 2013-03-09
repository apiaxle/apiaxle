crypto = require "crypto"
async  = require "async"

{ Controller } = require "apiaxle-base"
{ ApiUnknown, KeyError } = require "../../lib/error"

class exports.ApiaxleController extends Controller
  simpleBodyParser: ( req, res, next ) ->
    req.body = ""

    # add a body for PUTs and POSTs
    return next() if req.method in [ "HEAD", "GET" ]

    req.on "data", ( c ) -> req.body += c
    req.on "end", next

  subdomain: ( req, res, next ) ->
    # if we're called from a subdomain then let req know
    if parts = /^(.+?)\.api\./.exec req.headers.host
      req.subdomain = parts[1]
      return next()

    return next new ApiUnknown "No api specified (via subdomain)"

  api: ( req, res, next ) =>
    @app.model( "apiFactory" ).find req.subdomain, ( err, api ) ->
      return next err if err

      if not api?
        # no api found
        return next new ApiUnknown "'#{ req.subdomain }' is not known to us."

      req.api = api
      return next()

  authenticateWithKey: ( key, req, next ) ->
    @app.model( "keyFactory" ).find key, ( err, keyDetails ) =>
      return next err if err

      all = []

      # check the key is for this api
      req.api.supportsKey key, ( err, supported ) =>
        return cb err if err

        if supported is false
          return next new KeyError "'#{ key }' is not a valid key for '#{ req.subdomain }'"

        if keyDetails?.data.sharedSecret
          if not providedToken = ( req.query.apiaxle_sig or req.query.api_sig )
            return next new KeyError "A signature is required for this API."

          all.push ( cb ) =>
            @validateToken providedToken, key, keyDetails.data.sharedSecret, cb

        async.series all, ( err, results ) ->
          return next err if err

          keyDetails.data.key = key
          req.key = keyDetails

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
