async = require "async"

{ Redis } = require "../redis"

class exports.Counters extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "ct"

  apiHit: ( apiKey, response, cb ) ->
    multi = @multi()

    multi.hincrby [ apiKey, response ], @dayString(), 1
    multi.hincrby [ apiKey, response ], @monthString(), 1
    multi.hincrby [ apiKey, response ], @yearString(), 1

    multi.sadd [ apiKey, "all-response-types" ], response

    multi.exec cb

  _getTimeRange: ( apiKey, result, date, dateFunc, cb ) ->
    @hget [ apiKey, result ], dateFunc( date ), ( err, value ) ->
      return cb err if err

      return cb null, ( value or 0 )

  getPossibleResponseTypes: ( apiKey, cb ) ->
    @smembers [ apiKey, "all-response-types" ], cb

  getToday: ( apiKey, response, cb ) ->
    @getDay apiKey, response, new Date(), cb

  getThisMonth: ( apiKey, response, cb ) ->
    @getMonth apiKey, response, new Date(), cb

  getThisYear: ( apiKey, response, cb ) ->
    @getYear apiKey, response, new Date(), cb

  getHour: ( apiKey, response, date, cb ) ->
    @_getTimeRange apiKey, response, date, @hourString, cb

  getDay: ( apiKey, response, date, cb ) ->
    @_getTimeRange apiKey, response, date, @dayString, cb

  getMonth: ( apiKey, response, date, cb ) ->
    @_getTimeRange apiKey, response, date, @monthString, cb

  getYear: ( apiKey, response, date, cb ) ->
    @_getTimeRange apiKey, response, date, @yearString, cb
