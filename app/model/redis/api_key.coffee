{ Redis } = require "../redis"

class exports.ApiKey extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "key"

  get: ( key, cb ) ->
    @hgetall key, cb
