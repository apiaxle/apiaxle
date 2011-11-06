url = require "url"
request = require "request"

{ TimeoutError } = require "../../lib/error"
{ GatekeeperController } = require "./controller"

class CatchAll extends GatekeeperController
  path: ( ) -> "*"

  middleware: -> [ @subdomain, @api, @apiKey ]

  _request: ( options, cb ) ->
    request[ @constructor.verb ] options, ( err, apiRes, body ) ->
      # if we timeout then throw an error
      if err?.code is "ETIMEDOUT"
        return next new TimeoutError "API endpoint timed out."

      # copy headers from the endpoint
      for header, value of apiRes.headers
        res.header header, value

      # let the user know what they've got left
      res.header "X-GatekeeperProxy-Qps-Left", newQps
      res.header "X-GatekeeperProxy-Qpd-Left", newQpd

      # response with the same code as the endpoint
      return cb body, apiRes.statusCode

  execute: ( req, res, next ) ->
    { pathname } = url.parse req.url

    model = @app.model "apiLimits"

    { qps, qpd, key } = req.apiKey

    model.withinLimits key, { qps, qpd }, ( err, [ currentQps, currentQpd ] ) =>
      return next err if err

      model.apiHit key, ( err, [ newQps, newQpd ] ) =>
        return next err if err

        # copy the headers
        headers = req.headers
        delete headers.host

        options =
          url: "http://#{ req.api.endpoint }/#{ pathname }"
          followRedirects: true
          maxRedirects: req.api.maxRedirects
          timeout: req.api.endpointTimeout
          headers: headers

        # add a body for PUTs and POSTs
        options.body = req.body if req.body?

        @_request options, res.send

class exports.GetCatchall extends CatchAll
  @verb: "get"

class exports.PostCatchall extends CatchAll
  @verb: "post"

class exports.PutCatchall extends CatchAll
  @verb: "put"

class exports.DeleteCatchall extends CatchAll
  @verb: "delete"
