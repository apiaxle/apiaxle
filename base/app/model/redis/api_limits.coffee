# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
async = require "async"

{ QpsExceededError, QpdExceededError } = require "../../../lib/error"
{ Redis } = require "../redis"

class exports.ApiLimits extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "al"

  @qpdExpires = 86400
  @qpsExpires = 1

  qpsKey: ( key ) ->
    seconds = Math.floor( Date.now() / 1000 )

    return [ "qps", seconds, key ]

  qpdKey: ( key ) ->
    return [ "qpd", @dayString(), key ]

  setInitialQp: ( key, expires, qp, cb ) ->
    @setex key, expires, qp, ( err ) =>
      @app.logger.debug "Setting '#{ key }' to #{ qp } (expiring in #{ expires })"
      return cb err if err
      return cb null, qp

  apiHit: ( key, qpsLimit, qpdLimit, cb ) ->
    both = []

    if qpdLimit? and qpdLimit > 0
      both.push ( innerCb ) =>
        @qpdHit key, qpdLimit, innerCb

    if qpsLimit? and qpsLimit > 0
      both.push ( innerCb ) =>
        @qpsHit key, qpsLimit, innerCb

    async.series both, cb

  qpdHit: ( key, qpdLimit, cb ) ->
    qpdKey = @qpdKey( key )

    @qpHit qpdKey, @constructor.qpdExpires, qpdLimit, QpdExceededError, cb

  qpsHit: ( key, qpsLimit, cb ) ->
    qpsKey = @qpsKey( key )

    @qpHit qpsKey, @constructor.qpsExpires, qpsLimit, QpsExceededError, cb

  updateQpValue: ( qpKey, value, cb ) ->
    @set qpKey, value, cb

  qpHit: ( qpKey, qpExpires, qpLimit, QpErrorClass, cb ) ->
    # first, we need to do the initial get because it's possible the
    # qpKey doesn't exist already and we can't determine that from a
    # decr
    @get qpKey, ( err, currentQp ) =>
      return cb err if err

      # if currentQp is null then this is the first time we've used
      # it. Decrement the limit because this counts as a hit.
      if not currentQp?
        return @setInitialQp qpKey, qpExpires, ( qpLimit - 1 ), cb

      # we're allowed the call
      @decr qpKey, ( err, newQp ) =>
        current = parseInt( currentQp )
        return cb null, newQp if current > 0

        @app.logger.debug "Refusing hit as '#{ qpKey }' is #{ current }."

        # if we get here we've made too many calls
        return cb new QpErrorClass "Queries exceeded (#{ qpLimit } allowed).", null
