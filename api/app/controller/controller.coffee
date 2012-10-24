{ Controller } = require "apiaxle.base"
{ InvalidContentType, ApiUnknown, ApiKeyError } = require "../../lib/error"

exports.contentTypeRequired = ( accepted=[ "application/json" ] ) ->
  ( req, res, next ) ->
    ct = req.headers[ "content-type" ]

    if not ct
      return next new InvalidContentType "Content-type is a required header."

    if ct not in accepted
      return next new InvalidContentType "#{ ct } is not a supported content type."

    return next()

class ApiController extends Controller
  json: ( res, results ) ->
    output =
      meta:
        version: 1
      results: results

    return res.json output

class exports.ApiaxleController extends ApiController
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
        return @json res, keys

      # now bind the actual results to the keys
      @resolve model, keys, ( err, results ) =>
        return next err if err

        @json res, results
