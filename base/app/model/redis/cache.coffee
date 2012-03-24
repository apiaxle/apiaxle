async = require "async"

{ Redis } = require "../redis"

class exports.Cache extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "cache"

  add: ( key, ttl, content, cb ) ->
    @setex key, ttl, content, ( err ) ->
      cb err, ttl
