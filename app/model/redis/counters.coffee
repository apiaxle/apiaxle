async = require "async"

{ Redis } = require "../redis"

class exports.Counters extends Redis
  @instantiateOnStartup = true

  _hourString: ->
    now = new Date()
    return "#{ now.getFullYear()}#{ now.getMonth() }#{ now.getDay() }#{ now.getHour() }"

  _dayString: ->
    now = new Date()
    return "#{ now.getFullYear()}#{ now.getMonth() }#{ now.getDay() }"

  _MonthString: ->
    now = new Date()
    return "#{ now.getFullYear()}#{ now.getMonth() }"

  callsToday: ( user, apiKey, cb ) ->
    @get [ "counts", @_dayString(), user, apiKey ], cb

  apiHit: ( user, apiKey, cb ) ->
    # gk:test:counts:20111102:bob:api_key => hit count
    @incr [ "counts", @_dayString(), user, apiKey ], cb
