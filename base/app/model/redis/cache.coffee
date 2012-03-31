async = require "async"

{ Redis } = require "../redis"

class exports.Cache extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "cache"

  add: ( key, ttl, status, content, cb ) ->
    cache =
      body: content
      status: status

    @hmset key, cache, ( err ) =>
      return cb err if err

      @expire key, ttl, cb

  get: ( key, cb ) ->
    @hgetall key, ( err, cache ) =>
      return cb err if err

      { status, body } = cache
      return cb null, status, body
