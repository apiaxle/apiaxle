async = require "async"

{ QpsExceededError, QpdExceededError } = require "../../../lib/error"
{ Redis } = require "../redis"

class exports.ApiLimits extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "al"

  qpsKey: ( key ) ->
    seconds = Math.round( new Date().getTime() / 1000 )

    return [ "qps", seconds, key ]

  qpdKey: ( key ) ->
    return [ "qpd", @dayString(), key ]

  _setInitialQp: ( key, expires, qp, cb ) ->
    @setex key, expires, qp, ( err ) ->
      return cb err if err

      cb null, qp

  apiHit: ( key, qpsLimit, qpdLimit, cb ) ->
    both = []

    if qpsLimit? and qpsLimit > 0
      both.push ( innerCb ) =>
        @qpsHit key, qpsLimit, innerCb

    if qpdLimit? and qpdLimit > 0
      both.push ( innerCb ) =>
        @qpdHit key, qpdLimit, innerCb

    async.series both, cb

  qpdHit: ( key, qpdLimit, cb ) ->
    qpdKey = @qpdKey( key )

    @qpHit qpdKey, 86400, qpdLimit, QpdExceededError, cb

  qpsHit: ( key, qpsLimit, cb ) ->
    qpsKey = @qpsKey( key )

    @qpHit qpsKey, 2, qpsLimit, QpsExceededError, cb

  qpHit: ( qpKey, qpExpires, qpLimit, QpErrorClass, cb ) ->
    # first, we need to do the initial get because it's possible the
    # qpKey doesn't exist already and we can't determine that from a
    # decr
    multi = @multi()
    multi.get qpKey
    multi.decr qpKey

    multi.exec ( err, [ currentQp, newQp ] ) =>
      return cb err if err

      # if currentQp is null then this is the first time we've used
      # it. Decrement the limit because this counts as a hit.
      return @_setInitialQp qpKey, qpExpires, ( qpLimit - 1 ), cb if not currentQp?

      # we're allowed the call
      if currentQp > "0"
        return cb null, newQp

      # if we get here we've made too many calls
      return cb new QpErrorClass "Queries exceeded (#{ qpLimit } allowed).", null
