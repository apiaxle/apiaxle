async = require "async"
{ Redis } = require "../redis"

class exports.Stats extends Redis
  @instantiateOnStartup = true
  @smallKeyName         = "stats"
  # Amount of seconds to per record
  @precision            = 10

  hit: ( api, key, response, cb ) ->
    ts    = Math.floor( (new Date()).getTime()/1000 )
    ts    = Math.ceil( ts / Stats.precision ) * Stats.precision
    key   = [ "api", api, @dayString() ]

    @zrangebyscore key, ts, ts, ( err, res ) =>
      if res[0]
        stat = parseInt res[0].split( "|" )[1]
        console.log "STAT IS: ", stat
      else
        stat = 0

      stat += 1
      console.log "Setting", stat, res

      multi = @multi()
      multi.zrem key, ts
      multi.zadd key, ts, ts+"|"+stat
      multi.exec cb

#  _getTimeRange: ( key, result, date, dateFunc, cb ) ->
#    @hget [ key, result ], dateFunc( date ), ( err, value ) ->
#      return cb err if err
#
#      return cb null, ( value or 0 )
#
#  getPossibleResponseTypes: ( key, cb ) ->
#    @smembers [ key, "all-response-types" ], cb
#
#  getToday: ( key, response, cb ) ->
#    @getDay key, response, new Date(), cb
#
#  getThisMonth: ( key, response, cb ) ->
#    @getMonth key, response, new Date(), cb
#
#  getThisYear: ( key, response, cb ) ->
#    @getYear key, response, new Date(), cb
#
#  getMinute: ( key, response, date, cb ) ->
#    @_getTimeRange key, response, date, @minuteString, cb
#
#  getHour: ( key, response, date, cb ) ->
#    @_getTimeRange key, response, date, @hourString, cb
#
#  getDay: ( key, response, date, cb ) ->
#    @_getTimeRange key, response, date, @dayString, cb
#
#  getMonth: ( key, response, date, cb ) ->
#    @_getTimeRange key, response, date, @monthString, cb
#
#  getYear: ( key, response, date, cb ) ->
#    @_getTimeRange key, response, date, @yearString, cb
