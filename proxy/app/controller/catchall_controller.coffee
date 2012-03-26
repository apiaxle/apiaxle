url = require "url"
request = require "request"

{ TimeoutError } = require "../../lib/error"
{ ApiaxleController } = require "./controller"

class CatchAll extends ApiaxleController
  path: ( ) -> "*"

  middleware: -> [ @simpleBodyParser, @subdomain, @api, @apiKey ]

  _fetch: ( cacheTtl, options, api_key, cb ) ->
    @_httpRequest options, api_key, cb

  _cacheHash: ( url ) ->
    md5 = crypto.createHash "md5"
    console.log( @app.constructor.env )

    md5.update @app.constructor.env
    md5.update url

    return md5.digest "hex"

  _httpRequest: ( options, api_key, cb) ->
    counterModel = @app.model "counters"

    request[ @constructor.verb ] options, ( err, apiRes, body ) ->
      if err
        # if we timeout then throw an error
        if err.code is "ETIMEDOUT"
          counterModel.apiHit api_key, "timeout", ( counterErr, res ) ->
            return cb counterErr if counterErr
            return cb new TimeoutError( "API endpoint timed out." )
        else
          error = new Error "'#{ options.url }' yielded '#{ err.message }'"
          return cb error, null
      else
        # response with the same code as the endpoint
        counterModel.apiHit api_key, apiRes.statusCode, ( err, res ) ->
          return cb err, apiRes, body

  execute: ( req, res, next ) ->
    { pathname, query } = url.parse req.url, true

    # we should make this optional
    if query.apiaxle_key?
      delete query.apiaxle_key
    else
      delete query.api_key

    model = @app.model "apiLimits"

    { qps, qpd, key } = req.apiKey

    model.apiHit key, qps, qpd, ( err, [ newQps, newQpd ] ) =>
      if err
        counterModel = @app.model "counters"

        # collect the type of error (QpsExceededError or
        # QpdExceededError at the moment)
        type = err.constructor.name

        return counterModel.apiHit req.apiKey.key, type, ( counterErr, res ) ->
          return next counterErr if counterErr
          return next err

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
        timeout: req.api.endPointTimeout * 1000
        headers: headers

      options.body = req.body

      @_fetch req.globalCaching, options, req.apiKey.key, ( err, apiRes, body ) =>
        return next err if err

        # copy headers from the endpoint
        for header, value of apiRes.headers
          res.header header, value

        # let the user know what they've got left
        res.header "X-ApiaxleProxy-Qps-Left", newQps
        res.header "X-ApiaxleProxy-Qpd-Left", newQpd

        res.send body, apiRes.statusCode

class exports.GetCatchall extends CatchAll
  @verb: "get"

class exports.PostCatchall extends CatchAll
  @verb: "post"

class exports.PutCatchall extends CatchAll
  @verb: "put"

class exports.DeleteCatchall extends CatchAll
  @verb: "delete"
