async = require "async"

{ Redis } = require "../redis"

class exports.Qps extends Redis
  @instantiateOnStartup = true

  apiHit: ( user, apiKey, cb ) ->
