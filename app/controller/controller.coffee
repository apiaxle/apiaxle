{ Controller } = require "gatekeeper.base"
{ ApiUnknown, ApiKeyError } = require "../../lib/error"

class exports.GatekeeperController extends Controller
  subdomain: ( req, res, next ) ->
    # if we're called from a subdomain then let req know
    if parts = /^(.+?)\.api\./.exec req.headers.host
      req.subdomain = parts[1]

    return next()

  api: ( req, res, next ) =>
    # no subdomain means no api
    if not req.subdomain
      return next new ApiUnknown "No api specified (via subdomain)"

    @app.model( "api" ).find req.subdomain, ( err, api ) ->
      return next err if err

      if api?
        req.api = api
        return next()

      # no api found
      return next new ApiUnknown "'#{ req.subdomain }' is not known to us."

  apiKey: ( req, res, next ) =>
    key = req.query.api_key

    if not key
      return next new ApiKeyError "No api_key specified."

    @app.model( "apiKey" ).find key, ( err, keyDetails ) ->
      return next err if err

      # check the key is for this api
      if keyDetails?.forApi isnt req.subdomain
        return next new ApiKeyError "'#{ key }' is not a valid key for '#{ req.subdomain }'"

      keyDetails.key = key
      req.apiKey = keyDetails

      return next()