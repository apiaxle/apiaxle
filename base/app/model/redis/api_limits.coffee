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
      return cb err if err
      return cb null, qp

  apiHit: ( key, qpsLimit, qpdLimit, cb ) ->
    both = []

    if qpdLimit? and qpdLimit > 0
      both.push ( innerCb ) => @qpdHit key, qpdLimit, innerCb
    else
      both.push ( innerCb ) -> innerCb null, -1

    if qpsLimit? and qpsLimit > 0
      both.push ( innerCb ) => @qpsHit key, qpsLimit, innerCb
    else
      both.push ( innerCb ) -> innerCb null, -1

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
    # we're allowed the call
    @incr qpKey, ( err, newQp ) =>
      return cb err if err

      extra = []

      # when newQp is 1, redis has created a new key (rather than
      # incremented an old one). As it's a brand new key, we need to tell
      # Redis to expire it.
      if newQp is 1
        extra.push ( cb ) => @expire qpKey, qpExpires, cb

      if newQp > qpLimit or qpLimit is 0
        return cb new QpErrorClass "Queries exceeded (#{ qpLimit } allowed)."

      async.series extra, ( err ) ->
        return cb err if err
        return cb null, ( qpLimit - newQp )
