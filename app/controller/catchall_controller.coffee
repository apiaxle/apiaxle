url = require "url"
http = require "http"

{ Controller } = require "../controller"

class exports.RootController extends Controller
  @verb: "get"

  path: ( ) -> "*"

  middleware: -> [ @api, @apiKey ]

  execute: ( req, res, next ) ->
    { pathname } = url.parse req.url

    # copy the headers
    headers = req.headers
    delete headers.host

    options =
      host: req.api.endpoint
      path: pathname
      headers: headers

    model = @gatekeeper.model( "apiLimits" )

    { qps, qpd, key } = req.apiKey

    model.withinLimits key, { qps, qpd }, ( err, [ currentQps, currentQpd ] ) ->
      return next err if err

      model.apiHit key, ( err, [ newQps, newQpd ] ) ->
        return next err if err

        request = http.request options, ( apiRes ) ->
          data = ""

          apiRes.on "data", ( chunk ) -> data += chunk
          apiRes.on "error", console.log
          apiRes.on "end", ( ) ->
            res.header "X-gatekeeper-qps-left", newQps
            res.header "X-gatekeeper-qpd-left", newQpd

            res.send data, apiRes.statusCode

        request.end()
