crypto = require "crypto"

{ Controller } = require "apiaxle.base"
{ ApiUnknown, ApiKeyError } = require "../../lib/error"

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
    @app.model( "api" ).find req.subdomain, ( err, api ) ->
      return next err if err

      if not api?
        # no api found
        return next new ApiUnknown "'#{ req.subdomain }' is not known to us."

      req.api = api
      return next()

  authenticateWithKey: ( key, req, next ) ->
    @app.model( "apiKey" ).find key, ( err, keyDetails ) ->
      return next err if err

      # check the key is for this api
      if keyDetails?.forApi isnt req.subdomain
        return next new ApiKeyError "'#{ key }' is not a valid key for '#{ req.subdomain }'"

      if keyDetails?.sharedSecret
        # if the signature is missing then we cant go on
        if not sig = ( req.query.apiaxle_sig or req.query.api_sig )
          return next new ApiKeyError "A signature is required for this API."

        date = Math.floor( Date.now() / 1000 / 3 ).toString()

        md5 = crypto.createHash "md5"
        md5.update keyDetails.sharedSecret
        md5.update date
        md5.update key

        processed = md5.digest( "hex" )

        if processed isnt sig
          return next new ApiKeyError "Invalid signature (got #{processed})."

      keyDetails.key = key
      req.apiKey = keyDetails

      return next()

  apiKey: ( req, res, next ) =>
    key = ( req.query.apiaxle_key or req.query.api_key )

    if not key
      return next new ApiKeyError "No api_key specified."

    @authenticateWithKey( key, req, next )
