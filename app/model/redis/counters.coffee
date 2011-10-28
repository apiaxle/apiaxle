async = require "async"

{ Redis } = require "../redis"

class exports.Counters extends Redis
  @instantiateOnStartup = true

  callsToday: ( apiKey, cb ) ->
    @get [ "counts", @_dayString(), apiKey ], cb

  apiHit: ( apiKey, cb ) ->
    # gk:test:counts:20111102:bob:api_key => hit count
    @incr [ "counts", @_dayString(), apiKey ], cb
