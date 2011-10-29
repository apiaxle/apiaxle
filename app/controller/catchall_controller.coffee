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

    request = http.request options, ( apiRes ) ->
      data = ""

      apiRes.on "data", ( chunk ) -> data += chunk
      apiRes.on "error", console.log
      apiRes.on "end", ( ) -> res.send data, apiRes.statusCode

    request.end()
