{ Controller } = require "apiaxle.base"
{ NotFoundError, InvalidContentType, ApiUnknown, ApiKeyError } = require "../../lib/error"

class exports.ApiaxleController extends Controller
  # Used output data conforming to a standard Api Axle
  # format. Includes a metadata field
  json: ( res, results ) ->
    output =
      meta:
        version: 1
        status_code: res.statusCode
      results: results

    return res.json output

  # This function is used to satisfy the `?resolve=true` type
  # parameters. Given a bunch of keys, go off to the respective bits
  # of redis to resolve the data.
  resolve: ( model, keys, cb ) ->
    # build up the requests, grab the keys and zip into a new
    # hash
    multi = model.multi()
    multi.hgetall result for result in keys

    final = {}

    # grab the accumulated keys
    multi.exec ( err, accKeys ) ->
      return cb err if err

      i = 0
      for result in keys
        final[ result ] = accKeys[ i++ ]

      return cb null, final

  # Will decorate `req.key` with details of the key specified in the
  # `:key` parameter. If `valid_key_required` is truthful then an
  # error will be thrown if a valid key wasn't found.
  mwKeyDetails: ( valid_api_required=false ) ->
    ( req, res, next ) =>
      api_key = req.params.key

      @app.model( "keyFactory" ).find api_key, ( err, dbKey ) ->
        return next err if err

        if valid_api_required and not dbKey?
          return next new NotFoundError "#{ api_key } not found."

        req.key = dbKey

        return next()

  # Will decorate `req.api` with details of the api specified in the
  # `:api` parameter. If `valid_api_required` is truthful then an
  # error will be thrown if a valid api wasn't found.
  mwApiDetails: ( valid_api_required=false ) ->
    ( req, res, next ) =>
      api = req.params.api

      @app.model( "apiFactory" ).find api, ( err, dbApi ) ->
        return next err if err

        # do we /need/ the api to exist?
        if valid_api_required and not dbApi?
          return next new NotFoundError "#{ api } not found."

        req.api = dbApi

        return next()

  # Make a call require a specific content-type `accepted` can be an
  # array of good types. Without one of the valid content types
  # supplied there will be an error.
  mwContentTypeRequired: ( accepted=[ "application/json" ] ) ->
    ( req, res, next ) ->
      ct = req.headers[ "content-type" ]

      if not ct
        return next new InvalidContentType "Content-type is a required header."

      if ct not in accepted
        return next new InvalidContentType "#{ ct } is not a supported content type."

      return next()

class exports.ListController extends exports.ApiaxleController
  execute: ( req, res, next ) ->
    model = @app.model( @modelName() )

    model.range req.params.from, req.params.to, ( err, keys ) =>
      return next err if err

      # if we're not asked to resolve the items then just bung the
      # list back
      if not req.query.resolve?
        return @json res, keys

      # now bind the actual results to the keys
      @resolve model, keys, ( err, results ) =>
        return next err if err

        @json res, results
