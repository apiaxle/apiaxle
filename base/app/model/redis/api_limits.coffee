# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
async = require "async"

{ QpsExceededError, QpmExceededError, QpdExceededError } = require "../../../lib/error"
{ Redis } = require "../redis"

class exports.ApiLimits extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "al"

  @qpdExpires = 86400
  @qpmExpires = 60
  @qpsExpires = 1

  qpsKey: ( key, api ) ->
    seconds = Math.floor( Date.now() / 1000 )
    return [ "qps", seconds, api, key ]

  qpmKey: ( key, api ) ->
    return [ "qpm", @minuteString(), api, key ]

  qpdKey: ( key, api ) ->
    return [ "qpd", @dayString(), api, key ]

  setInitialQp: ( key, expires, qp, cb ) ->
    @setex key, expires, qp, ( err ) =>
      return cb err if err
      return cb null, qp

  apiHit: ( key, api, qpsLimit, qpmLimit, qpdLimit, cb ) ->
    all = []

    if qpdLimit? and qpdLimit > 0
      all.push ( innerCb ) => @qpdHit key, api, qpdLimit, innerCb
    else
      all.push ( innerCb ) -> innerCb null, -1

    if qpmLimit? and qpmLimit > 0
      all.push ( innerCb ) => @qpmHit key, api, qpmLimit, innerCb
    else
      all.push ( innerCb ) -> innerCb null, -1

    if qpsLimit? and qpsLimit > 0
      all.push ( innerCb ) => @qpsHit key, api, qpsLimit, innerCb
    else
      all.push ( innerCb ) -> innerCb null, -1

    async.series all, cb

  qpdHit: ( key, api, qpdLimit, cb ) ->
    qpdKey = @qpdKey( key, api )
    @qpHit qpdKey, @constructor.qpdExpires, qpdLimit, QpdExceededError, cb

  qpmHit: ( key, api, qpmLimit, cb ) ->
    qpmKey = @qpmKey( key, api )
    @qpHit qpmKey, @constructor.qpmExpires, qpmLimit, QpmExceededError, cb

  qpsHit: ( key, api, qpsLimit, cb ) ->
    qpsKey = @qpsKey( key, api )
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
