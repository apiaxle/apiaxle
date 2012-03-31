async = require "async"

{ Redis } = require "../redis"

class exports.Cache extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "cache"

  add: ( key, ttl, status, contentType, content, cb ) ->
    cache =
      body: content
      status: status
      contentType: contentType

    @hmset key, cache, ( err ) =>
      return cb err if err

      @expire key, ttl, cb

  get: ( key, cb ) ->
    @hgetall key, ( err, cache ) =>
      return cb err if err

      { status, contentType, body } = cache
      return cb null, parseInt( status ), contentType, body
