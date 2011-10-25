{ Redis } = require "../redis"

class exports.User extends Redis
  @instantiateOnStartup = true

  _dateString: ->
    now = new Date()
    return "#{ now.getFullYear()}#{ now.getMonth() }#{ now.getDay() }"

  callsToday: ( apiKey, cb ) ->
    @get "#{ @_dateString() }:#{ apiKey }", cb

  apiHit: ( apiKey, cb ) ->
    @incr "#{ @_dateString() }:#{ apiKey }", cb
