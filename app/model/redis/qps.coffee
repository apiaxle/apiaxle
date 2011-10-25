async = require "async"

{ QpsError } = require "../../../lib/error"
{ Redis } = require "../redis"

class exports.Qps extends Redis
  @instantiateOnStartup = true

  _setInitialCps: ( key, options, cb ) ->
    @set [ key ], options.qps, ( err, res ) =>
      return cb err if err

      # expires in a second
      @expire [ key ], 1, ( err, result ) =>
        return cb err if err

        return cb null, options.qps

  # Register an API hit, by:
  # `options` can contain:
  # * qps - Queries per second (integer).
  # * cpd - Calls per day.
  apiHit: ( user, apiKey, options, cb ) ->
    # join the key here to save cycles
    key = [ user, apiKey ].join ":"

    # how many calls have we got left (if any)?
    @get [ key ], ( err, callsLeft ) =>
      return cb err if err

      # no key set yet (or it expired)
      if not callsLeft?
        return @_setInitialCps key, options, cb

      # no more calls left
      if callsLeft <= 0
        return cb new QpsError "Queries per second exceeded (#{ options.qps} allocated)."
