url = require "url"
request = require "request"

{ TimeoutError } = require "../../lib/error"
{ Controller } = require "../controller"

class exports.RootController extends Controller
  @verb: "get"

  path: ( ) -> "*"

  middleware: -> [ @api, @apiKey ]

  execute: ( req, res, next ) ->
    { pathname } = url.parse req.url

    model = @gatekeeper.model "apiLimits"

    { qps, qpd, key } = req.apiKey

    model.withinLimits key, { qps, qpd }, ( err, [ currentQps, currentQpd ] ) ->
      return next err if err

      model.apiHit key, ( err, [ newQps, newQpd ] ) ->
        return next err if err

        # copy the headers
        headers = req.headers
        delete headers.host

        options =
          url: "http://#{ req.api.endpoint }/#{ pathname }"
          timeout: req.api.endpointTimeout
          headers: headers

        request.get options, ( err, apiRes, body ) ->
          if err?.code is "ETIMEDOUT"
            return next new TimeoutError "API endpoint timed out."

          res.send body, apiRes.statusCode
