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
    multi = @multi()

    multi.get key
    multi.ttl key

    multi.exec ( err, [ callsLeft, ttl ] ) =>
      return cb err if err

      # no key set yet (or it expired). We have to check for ttl being
      # 0 here because there's a bug in redis which means a key lives
      # whilst its ttl is 0
      if not callsLeft? or ttl is 0
        return @_setInitialQp key, qpLimit, expires, cb

      # no more calls left
      if callsLeft is "0"
        return cb new exceedErrorClass "#{ qpLimit} allowed."

      return cb null, callsLeft
