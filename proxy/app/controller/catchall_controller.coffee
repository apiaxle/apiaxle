url = require "url"
crypto = require "crypto"
request = require "request"
debug = require( "debug" )( "aa:catchall" )

{ KeyDisabled,
  ApiDisabled,
  EndpointMissingError,
  EndpointTimeoutError,
  ConnectionError,
  DNSError } = require "../../lib/error"
{ ApiaxleController } = require "./controller"

class CatchAll extends ApiaxleController
  @cachable: false

  path: ( ) -> "*"

  middleware: -> [ @simpleBodyParser,
                   @subdomain,
                   @api,
                   @key,
                   @keyrings ]

  _cacheHash: ( url ) ->
    md5 = crypto.createHash "md5"
    md5.update @app.options.env
    md5.update url
    md5.digest "hex"

  _cacheTtl: ( req, cb ) ->
    # no caching
    if not this.constructor.cachable
      return cb null, false, 0

    mustRevalidate = false

    # cache-control might want us to do something. We only care about
    # a few of the pragmas
    if cacheControl = @_parseCacheControl req

      # we might have to revalidate if the client has asked us to
      mustRevalidate = ( not not cacheControl[ "proxy-revalidate" ] )

      # don't cache anything
      if cacheControl[ "no-cache" ]
        return cb null, mustRevalidate, 0

      # explicit ttl
      if ttl = cacheControl[ "s-maxage" ]
        return cb null, mustRevalidate, ttl

    # return the global cache
    return cb null, mustRevalidate, req.api.data.globalCache

  # returns an object which looks like this (with all fields being
  # optional):
  #
  # {
  #   "s-maxage" : <seconds>
  #   "proxy-revalidate" : true|false
  #   "no-cache" : true|false
  # }
  _parseCacheControl: ( req ) ->
    return {} unless req.headers["cache-control"]

    res = {}
    header = req.headers["cache-control"].replace new RegExp( " ", "g" ), ""

    for directive in header.split ","
      [ key, value ] = directive.split "="
      value or= true

      res[ key ] = value

    return res

  _fetch: ( req, options, outerCb ) ->
    # check for caching, pass straight through if we don't want a
    # cache.
    @_cacheTtl req, ( err, mustRevalidate, cacheTtl ) =>
      return outerCb err if err

      if cacheTtl is 0 or mustRevalidate
        return @_httpRequest options, req.subdomain, req.key.data.key, req.keyrings, outerCb

      cache = @app.model "cache"
      key = @_cacheHash options.url

      cache.get key, ( err, status, contentType, body ) =>
        return outerCb err if err

        if body
          statsModel = @app.model "stats"

          @app.logger.debug "Cache hit: #{options.url}"
          return statsModel.hit req.subdomain, req.key.data.key, req.keyrings, "cached", status, ( err, res ) ->
            fakeResponse =
              statusCode: status
              headers:
                "Content-Type": contentType

            return outerCb err, fakeResponse, body

        @app.logger.debug "Cache miss: #{options.url}"

        # means we've a cache miss and so need to make a real request
        @_httpRequest options, req.subdomain, req.key.data.key, req.keyrings, ( err, apiRes, body ) =>
          return outerCb err if err

          # do I really need to check both?
          contentType = apiRes.headers["Content-Type"] or apiRes.headers["content-type"]

          cache.add key, cacheTtl, apiRes.statusCode, contentType, body, ( err ) =>
            return outerCb err, apiRes, body

  @ENDPOINT_ERROR_MAP =
    ETIMEDOUT: ( ) -> new EndpointTimeoutError "API endpoint timed out."
    ENOTFOUND: ( ) -> new EndpointMissingError "API endpoint could not be found."
    EADDRINFO: ( ) -> new DNSError "API endpoint could not be resolved."
    ECONNREFUSED: ( ) -> new ConnectionError "API endpoint could not be reached."

  _httpRequest: ( options, api, api_key, keyrings, cb ) ->
    statsModel = @app.model "stats"

    @app.logger.debug "#{ @constructor.verb }ing '#{ options.url }'"
    request[ @constructor.verb ] options, ( err, apiRes, body ) =>
      if err
        if err_func = @constructor.ENDPOINT_ERROR_MAP[ err.code ]
          new_err = err_func()

          return statsModel.hit api, api_key, keyrings, "error", new_err.name, ( err, res ) ->
            return cb new_err

        # if we're here its a new kind of error, don't want to call
        # statsModel.hit without knowing what it is for now
        @app.logger.warn "Error won't be statistically logged: '#{ err.message }'"
        error = new Error "'#{ options.url }' yielded '#{ err.message }'."
        return cb error, null

      # response with the same code as the endpoint
      return statsModel.hit api, api_key, keyrings, "uncached", apiRes.statusCode, ( err, res ) ->
        return cb err, apiRes, body

  execute: ( req, res, next ) ->
    if req.api.isDisabled()
      return next new ApiDisabled "This API has been disabled."

    if req.key.isDisabled()
      return next new KeyDisabled "This API key has been disabled."

    { pathname, query } = url.parse req.url, true

    # we should make this optional
    if query.apiaxle_sig?
      delete query.apiaxle_sig
    else
      delete query.api_sig

    # we also should make this optional
    if query.apiaxle_key?
      delete query.apiaxle_key
    else
      delete query.api_key

    model = @app.model "apilimits"

    { qps, qpd, key } = req.key.data

    model.apiHit key, qps, qpd, ( err, [ newQps, newQpd ] ) =>
      if err
        statsModel = @app.model "stats"

        # collect the type of error (QpsExceededError or
        # QpdExceededError at the moment)
        type = err.name

        return statsModel.hit req.subdomain, req.key.data.key, req.keyrings, "error", type, ( counterErr, res ) ->
          return next counterErr if counterErr
          return next err

      # copy the headers
      headers = req.headers
      delete headers.host

      endpointUrl = "#{ req.api.data.protocol }://#{ req.api.data.endPoint }"

      # here we support a default path for the request. This makes
      # sense with people like the BBC who have many APIs all sitting
      # on the one domain.
      if ( defaultPath = req.api.data.defaultPath )
        endpointUrl += defaultPath

      # the bit of the path that was actually requested
      endpointUrl += pathname

      if query
        endpointUrl += "?"
        newStrings = ( "#{ key }=#{ value }" for key, value of query )
        endpointUrl += newStrings.join( "&" )

      options =
        url: endpointUrl
        followRedirects: true
        maxRedirects: req.api.data.endPointMaxRedirects
        timeout: req.api.data.endPointTimeout * 1000
        headers: headers
        strictSSL: req.api.data.strictSSL

      options.body = req.body if req.body

      @_fetch req, options, ( err, apiRes, body ) =>
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
