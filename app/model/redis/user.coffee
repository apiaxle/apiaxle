async = require "async"

{ Redis } = require "../redis"

class exports.User extends Redis
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
    @get "#{ @_dayString() }:#{ user }:#{ apiKey }", cb

  apiHit: ( user, apiKey, cb ) ->
    @incr "#{ @_dayString() }:#{ user }:#{ apiKey }", cb
