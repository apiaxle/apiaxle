{ Controller } = require "apiaxle.base"
{ ApiUnknown, KeyError } = require "../../lib/error"

class exports.ApiaxleController extends Controller
  docs: -> ""

class exports.ListController extends exports.ApiaxleController
  execute: ( req, res, next ) ->
    model = @app.model( @modelName() )

    model.range req.params.from, req.params.to, ( err, results ) ->
      return next err if err

      # if we're not asked to resolve the items then just bung the
      # list back
      if not req.query.resolve?
        return res.json results

      # build up the requests, grab the results and zip into a new
      # hash
      multi = model.multi()
      multi.hgetall result for result in results

      final = { }

      # grab the accumulated results
      multi.exec ( err, accResults ) ->
        return next err if err

        i = 0
        for result in results
          final[ result ] = accResults[ i++ ]

        return res.json final
