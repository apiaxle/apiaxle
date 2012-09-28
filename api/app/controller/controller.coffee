{ Controller } = require "apiaxle.base"
{ ApiUnknown, KeyError } = require "../../lib/error"

class exports.ApiaxleController extends Controller
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
