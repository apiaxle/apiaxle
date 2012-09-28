{ Controller } = require "apiaxle.base"
{ NotFoundError, InvalidContentType, ApiUnknown, ApiKeyError } = require "../../lib/error"

class exports.ApiaxleController extends Controller
  mwContentTypeRequired: ( accepted=[ "application/json" ] ) ->
    ( req, res, next ) ->
      ct = req.headers[ "content-type" ]

      if not ct
        return next new InvalidContentType "Content-type is a required header."

      if ct not in accepted
        return next new InvalidContentType "#{ ct } is not a supported content type."

      return next()

  mwApiDetailsRequired: ( ) ->
    ( req, res, next ) =>
      api = req.params.api

      @app.model( "api" ).find api, ( err, dbApi ) ->
        return next err if err

        if not dbApi?
          return next new NotFoundError "#{ api } not found."

        req.api = dbApi

        return next()


  mwApiDetails: ( ) ->
    ( req, res, next ) =>
      api = req.params.api

      @app.model( "api" ).find api, ( err, dbApi ) ->
        return next err if err

        req.api = dbApi

        return next()

  docs: -> ""

  resolve: ( model, keys, cb ) ->
    # build up the requests, grab the keys and zip into a new
    # hash
    multi = model.multi()
    multi.hgetall result for result in keys

    final = { }

    # grab the accumulated keys
    multi.exec ( err, accKeys ) ->
      return cb err if err

      i = 0
      for result in keys
        final[ result ] = accKeys[ i++ ]

      return cb null, final

class exports.ListController extends exports.ApiaxleController
  execute: ( req, res, next ) ->
    model = @app.model( @modelName() )

    model.range req.params.from, req.params.to, ( err, keys ) =>
      return next err if err

      # if we're not asked to resolve the items then just bung the
      # list back
      if not req.query.resolve?
        return res.json keys

      # now bind the actual results to the keys
      @resolve model, keys, ( err, results ) ->
        return next err if err

        res.json results
