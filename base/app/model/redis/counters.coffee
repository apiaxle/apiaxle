async = require "async"

{ Redis } = require "../redis"

class exports.Counters extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "ct"

  apiHit: ( api, key, response, cb ) ->
    multi = @multi()

    multi.hincrby [ "key", key, response ], @minuteString(), 1
    multi.hincrby [ "key", key, response ], @hourString(), 1
    multi.hincrby [ "key", key, response ], @dayString(), 1
    multi.hincrby [ "key", key, response ], @monthString(), 1
    multi.hincrby [ "key", key, response ], @yearString(), 1

    # Record per day stats
    multi.hincrby [ "key", key, @dayString(), response ], @dayString(), 1
    multi.hincrby [ "key", key, @dayString(), response ], @hourString(), 1
    multi.hincrby [ "key", key, @dayString(), response ], @minuteString(), 1

    multi.sadd [ "key", key, "all-response-types" ], response

    multi.hincrby [ "api", api, response ], @minuteString(), 1
    multi.hincrby [ "api", api, response ], @hourString(), 1
    multi.hincrby [ "api", api, response ], @dayString(), 1
    multi.hincrby [ "api", api, response ], @monthString(), 1
    multi.hincrby [ "api", api, response ], @yearString(), 1

    # Record per day stats
    multi.hincrby [ "api", api, @dayString(), response ], @dayString(), 1
    multi.hincrby [ "api", api, @dayString(), response ], @hourString(), 1
    multi.hincrby [ "api", api, @dayString(), response ], @minuteString(), 1

    multi.sadd [ "api", api, "all-response-types" ], response

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
