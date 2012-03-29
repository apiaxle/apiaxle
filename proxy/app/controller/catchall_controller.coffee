url = require "url"
crypto = require "crypto"
request = require "request"

{ TimeoutError } = require "../../lib/error"
{ ApiaxleController } = require "./controller"

class CatchAll extends ApiaxleController
  @cachable: false

  path: ( ) -> "*"

  middleware: -> [ @simpleBodyParser, @subdomain, @api, @apiKey ]

  _cacheHash: ( url ) ->
    md5 = crypto.createHash "md5"
    md5.update @app.constructor.env
    md5.update url
    md5.digest "hex"

  # TODO: make sure to inc counters!
  _fetch: ( cacheTtl, options, api_key, outerCb ) ->
    # check for caching, pass straight through if we don't want a
    # cache (the 0 is a string because it comes straight from redis).
    if cacheTtl is "0" or not @.constructor.cachable
      return @_httpRequest options, api_key, outerCb

    cache = @app.model "cache"
    key = @_cacheHash options.url

    cache.get key, ( err, body ) =>
      return outerCb err if err

      # TODO: does anything need setting in terms of the
      # apiresponse? Should we have cached the headers?
      return outerCb null, { }, body if body

      # means we've a cache miss and so need to make a real request
      @_httpRequest options, api_key, ( err, apiRes, body ) =>
        return outerCb err if err

        cache.add key, cacheTtl, body, ( err ) =>
          return outerCb err, apiRes, body

  _httpRequest: ( options, key, cb) ->
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

      @_fetch req.api.globalCache, options, req.apiKey.key, ( err, apiRes, body ) =>
        return next err if err

        # copy headers from the endpoint
        for header, value of apiRes.headers
          res.header header, value

        # let the user know what they've got left
        res.header "X-ApiaxleProxy-Qps-Left", newQps
        res.header "X-ApiaxleProxy-Qpd-Left", newQpd

        res.send body, apiRes.statusCode

class exports.GetCatchall extends CatchAll
  @cachable: true

  @verb: "get"

class exports.PostCatchall extends CatchAll
  @verb: "post"

class exports.PutCatchall extends CatchAll
  @verb: "put"

class exports.DeleteCatchall extends CatchAll
  @verb: "delete"
