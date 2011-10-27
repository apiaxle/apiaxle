async = require "async"

{ QpsExceededError, QpdExceededError } = require "../../../lib/error"
{ Redis } = require "../redis"

class exports.ApiLimits extends Redis
  @instantiateOnStartup = true

  # Where `limits` might contain:
  # * qps - queries per second
  # * qpd - queries per day
  withinLimits: ( user, apiKey, limits, cb ) ->
    checks = [ ]

    if limits.qps
      checks.push ( cb ) =>
        @withinQps user, apiKey, limits.qps, cb

    if limits.qpd
      checks.push ( cb ) =>
        @withinQpd user, apiKey, limits.qpd, cb

    async.series checks, cb

  apiHit: ( user, apiKey, cb ) ->
    multi = @multi()

    multi.decr @qpsKey( user, apiKey )
    multi.decr @qpdKey( user, apiKey )

    multi.exec cb

  withinQps: ( user, apiKey, qps, cb ) ->
    @_withinLimit @qpsKey( user, apiKey ), 1, qps, QpsExceededError, cb

  withinQpd: ( user, apiKey, qpd, cb ) ->
    @_withinLimit @qpdKey( user, apiKey ), 86000, qpd, QpdExceededError, cb

  qpsKey: ( user, apiKey ) ->
    return [ "qps", user, apiKey ]

  qpdKey: ( user, apiKey ) ->
    return [ "qpd", @_dayString(), user, apiKey ]

  _setInitialQp: ( key, qp, expires, cb ) ->
    @set key, qp, ( err, res ) =>
      return cb err if err

      # expires in a second
      @expire key, expires, ( err, result ) =>
        return cb err if err

        return cb null, qp

  _withinLimit: ( key, expires, qpLimit, exceedErrorClass, cb ) ->
    # how many calls have we got left (if any)?
    @get key, ( err, callsLeft ) =>
      return cb err if err

      # no key set yet (or it expired).
      if not callsLeft?
        return @_setInitialQp key, qpLimit, expires, cb

      # If the value is -1 that means we've possibly decremented a key
      # just as it expired so we just build a new one. So make a new
      # key and subtract the hit they owe us from it.
      if callsLeft is "-1"
        return @_setInitialQp key, ( qpLimit - 1 ), expires, cb

      # no more calls left
      if callsLeft is "0"
        return cb new exceedErrorClass "#{ qpLimit} allowed."

      return cb null, callsLeft
