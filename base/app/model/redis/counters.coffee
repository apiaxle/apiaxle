async = require "async"

{ Redis } = require "../redis"

class exports.Counters extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "ct"

  apiHit: ( key, response, cb ) ->
    multi = @multi()

    multi.hincrby [ key, response ], @minuteString(), 1
    multi.hincrby [ key, response ], @hourString(), 1
    multi.hincrby [ key, response ], @dayString(), 1
    multi.hincrby [ key, response ], @monthString(), 1
    multi.hincrby [ key, response ], @yearString(), 1

    multi.sadd [ key, "all-response-types" ], response

    multi.exec cb

  _getTimeRange: ( key, result, date, dateFunc, cb ) ->
    @hget [ key, result ], dateFunc( date ), ( err, value ) ->
      return cb err if err

      return cb null, ( value or 0 )

  getPossibleResponseTypes: ( key, cb ) ->
    @smembers [ key, "all-response-types" ], cb

  getToday: ( key, response, cb ) ->
    @getDay key, response, new Date(), cb

  getThisMonth: ( key, response, cb ) ->
    @getMonth key, response, new Date(), cb

  getThisYear: ( key, response, cb ) ->
    @getYear key, response, new Date(), cb

  getMinute: ( key, response, date, cb ) ->
    @_getTimeRange key, response, date, @minuteString, cb

  getHour: ( key, response, date, cb ) ->
    @_getTimeRange key, response, date, @hourString, cb

  getDay: ( key, response, date, cb ) ->
    @_getTimeRange key, response, date, @dayString, cb

  getMonth: ( key, response, date, cb ) ->
    @_getTimeRange key, response, date, @monthString, cb

  getYear: ( key, response, date, cb ) ->
    @_getTimeRange key, response, date, @yearString, cb
