async = require "async"

{ QpsExceededError, QpdExceededError } = require "../../../lib/error"
{ Redis } = require "../redis"

class exports.ApiLimits extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "al"

  # Where `limits` might contain:
  # * qps - queries per second
  # * qpd - queries per day
  withinLimits: ( apiKey, limits, cb ) ->
    checks = [ ]

    if limits.qps
      checks.push ( cb ) =>
        @withinQps apiKey, limits.qps, cb

    if limits.qpd
      checks.push ( cb ) =>
        @withinQpd apiKey, limits.qpd, cb

    async.series checks, cb

  apiHit: ( apiKey, cb ) ->
    multi = @multi()

    multi.decr @qpsKey( apiKey )
    multi.decr @qpdKey( apiKey )

    multi.exec cb

  withinQps: ( apiKey, qps, cb ) ->
    @_withinLimit @qpsKey( apiKey ), 1, qps, QpsExceededError, cb

  withinQpd: ( apiKey, qpd, cb ) ->
    @_withinLimit @qpdKey( apiKey ), 86000, qpd, QpdExceededError, cb

  qpsKey: ( apiKey ) ->
    seconds = Math.round( new Date().getTime() / 1000 )

    return [ "qps", seconds, apiKey ]

  qpdKey: ( apiKey ) ->
    return [ "qpd", @_dayString(), apiKey ]

  _setInitialQp: ( key, qp, expires, cb ) ->
    @setex key, expires, qp, ( err ) ->
      return cb err if err

      cb null, qp

  _withinLimit: ( key, expires, qpLimit, exceedErrorClass, cb ) ->
    @get key, ( err, callsLeft ) =>
      return cb err if err

      # no key set yet (or it expired).
      if not callsLeft?
        return @_setInitialQp key, qpLimit, expires, cb

      # no more calls left
      if callsLeft <= "0"
        return cb new exceedErrorClass "#{ qpLimit} allowed."

      return cb null, callsLeft
