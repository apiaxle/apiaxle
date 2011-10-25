async = require "async"

{ Redis } = require "../redis"

class exports.Qps extends Redis
  @instantiateOnStartup = true

  _setInitialCps: ( key, options, cb ) ->
    @set [ key ], options.qps, ( err, res ) =>
      return cb err if err

      @expire [ key ], options.qps, ( err, result ) =>
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
      return @_setInitialCps key, options, cb if not callsLeft?
