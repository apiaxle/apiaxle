async = require "async"

{ QpsExceededError, QpdExceededError } = require "../../../lib/error"
{ Redis } = require "../redis"

class exports.ApiLimits extends Redis
  @instantiateOnStartup = true

  _setInitialQps: ( key, qps, cb ) ->
    @set [ key ], qps, ( err, res ) =>
      return cb err if err

      # expires in a second
      @expire [ key ], 1, ( err, result ) =>
        return cb err if err

        return cb null, qps

  withinQps: ( user, apiKey, qps, cb ) ->
    @withinLimit @qpsKey( user, apiKey ), qps, cb

  withinQpd: ( user, apiKey, qpd, cb ) ->
    @withinLimit @qpdKey( user, apiKey ), qpd, cb

  _withinLimit: ( key, qpLimit, cb ) ->
    # join the key here to save cycles
    key = key.join ":"

    # how many calls have we got left (if any)?
    @get [ key ], ( err, callsLeft ) =>
      return cb err if err

      # no key set yet (or it expired)
      if not callsLeft?
        return @_setInitialQps key, qpLimit, cb

      # no more calls left
      if callsLeft <= 0
        return cb new QpsExceededError "#{ qpLimit} allowed per second."

      return cb null, callsLeft

  qpsKey: ( user, apiKey ) ->
    return [ "qps", user, apiKey ]

  qpdKey: ( user, apiKey ) ->
    return [ "qpd", @_dayString(), user, apiKey ]

  _setInitialQpd: ( key, qpd, cb ) ->
    @set [ key ], qpd, ( err, res ) =>
      return cb err if err

      # expires in a day
      @expire [ key ], 86400, ( err, result ) =>
        return cb err if err

        return cb null, qpd
