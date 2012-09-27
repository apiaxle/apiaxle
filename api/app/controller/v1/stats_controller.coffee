_ = require "underscore"

{ ApiaxleController } = require "../controller"
{ NotFoundError, InvalidDateFormat } = require "../../../lib/error"

keyRequired = ( app ) ->
  ( req, res, next ) ->
    api_key = req.params.key

    app.model( "key" ).find api_key, ( err, dbKey ) ->
      return next err if err

      if not dbKey?
        return next new NotFoundError "#{ api_key } not found."

      req.key = dbKey

      return next()

class exports.ViewAllStatsForKey extends ApiaxleController
  @verb = "get"

  docs: ->
    """Get the statistics for key `:key`.

    ### Returns:

    * Object where the keys represent the HTTP status code of the
      endpoint or the error returned by apiaxle (QpsExceededError, for
      example). Each object contains date to hit count pairs.
    """

  middleware: -> [ keyRequired( @app ) ]

  path: -> "/v1/stats/:key/all"

  execute: ( req, res, next ) ->
    model = @app.model "counters"
    model.getPossibleResponseTypes req.params.key, ( err, types ) ->
      return next err if err

      multi = model.multi()

      for type in types
        do ( type ) ->
          multi.hgetall [ req.params.key, type ]

      multi.exec ( err, results ) ->
        return next err if err

        # build up the output structure
        output = {}

        for type in types
          output[ type ] = results.shift()

        res.json output
