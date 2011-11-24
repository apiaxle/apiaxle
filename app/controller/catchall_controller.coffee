url = require "url"
request = require "request"

{ TimeoutError } = require "../../lib/error"
{ GatekeeperController } = require "./controller"

class CatchAll extends GatekeeperController
  path: ( ) -> "*"

  middleware: -> [ @subdomain, @api, @apiKey ]

  _httpRequest: ( options, cb) ->
    request[ @constructor.verb ] options, ( err, apiRes, body ) ->
      if err
        # if we timeout then throw an error
        if err?.code is "ETIMEDOUT"
          return next new TimeoutError "API endpoint timed out."

        error = new Error "'#{ options.url }' yielded '#{ err.message }'"
        return cb error, null

      # response with the same code as the endpoint
      return cb err, apiRes, body

  execute: ( req, res, next ) ->
    { pathname, query } = url.parse req.url, true

    # we should make this optional
    if query.gatekeeper_key?
      delete query.gatekeeper_key
    else
      delete query.api_key

    model = @app.model "apiLimits"

    { qps, qpd, key } = req.apiKey

    model.apiHit key, qps, qpd, ( err, [ newQps, newQpd ] ) =>
      return next err if err

      # copy the headers
      headers = req.headers
      delete headers.host

      endpointUrl = "http://#{ req.api.endPoint }/#{ pathname }"
      if query
        endpointUrl += "?"
        newStrings = ( "#{ key }=#{ value }" for key, value of query )
        endpointUrl += newStrings.join( "&" )

      options =
        url: endpointUrl
        followRedirects: true
        maxRedirects: req.api.endPointMaxRedirects
        timeout: req.api.endPointTimeout
        headers: headers

      # add a body for PUTs and POSTs
      options.body = req.body if req.body?

      @_httpRequest options, ( err, apiRes, body ) =>
        return next err if err

        # copy headers from the endpoint
        for header, value of apiRes.headers
          res.header header, value

        # let the user know what they've got left
        res.header "X-GatekeeperProxy-Qps-Left", newQps
        res.header "X-GatekeeperProxy-Qpd-Left", newQpd

        res.send body, apiRes.statusCode

class exports.GetCatchall extends CatchAll
  @verb: "get"

class exports.PostCatchall extends CatchAll
  @verb: "post"

class exports.PutCatchall extends CatchAll
  @verb: "put"

class exports.DeleteCatchall extends CatchAll
  @verb: "delete"
