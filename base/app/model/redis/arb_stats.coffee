# Store and access real time hits per second
_ = require "lodash"
async = require "async"
debug = require( "debug" )( "aa:stats" )

# a bunch of constants to make things more readable
tconst = require "../../../lib/time_constants"

{ Redis } = require "../redis"

class Stat extends Redis
  constructor: ( args... ) ->
    # denormalise the keys above so that we can access them quickly
    # later
    @gran_names = _.keys @constructor.granularities

    super args...

  @granularities =
    second:
      value: tconst.seconds 1
      redis_ttl: tconst.hours 2

    minute:
      value: tconst.minutes 1
      redis_ttl: tconst.days 1

    hour:
      value: tconst.hours 1
      redis_ttl: tconst.weeks 1

    day:
      value: tconst.days 1
      redis_ttl: tconst.years 2

  # retuns an array of valid times for GRAN.
  _getValidTimeRange: ( gran, from, to=@toSeconds() ) ->
    { value } = @constructor.granularities[gran]

    ticks = []
    current_click = @roundedTimestamp from

    while current_click <= to
      ticks.push current_click
      current_click += value

    return ticks

  # get the counter values. Args are:
  #  * names (array) - the name of the stat to fetch
  #  * granularity - the name of the granularity results are for.
  #  * from - where the stats should start from (in seconds).
  #  * to - where the stats should end (in seconds).
  getCounterValues: ( names, gran, from, to, cb ) ->
    if not names or names.length is 0
      return cb Error "getCounterValues requires a list of names."

    if gran not in @gran_names
      return cb Error "Granularity must be one of #{ @gran_names.join(', ') }"

    [ rounded_ttl, rounded_ts ] = @getKeyValueTimestamps gran

    # collect the keys we want
    wantedTs = @_getValidTimeRange gran, from, to

    all = []
    for name in names
      do( name ) =>
        all.push ( cb ) =>
          multi = @multi()

          redis_key = [ name, gran, rounded_ttl ]

          # for each wanted timestamp, collect the values
          multi.hget( redis_key, hashKey ) for hashKey in wantedTs

          multi.exec ( err, results ) =>
            return cb err if err

            # we might want to do something with the values (like
            # parse JSON)
            filtered = if @_outputValueFilter?
              _.map( results, @_outputValueFilter )
            else
              results

            return cb null, _.pick( _.object( wantedTs, filtered ), ( v ) -> v? )

    async.parallel all, ( err, results ) ->
      return cb err if err
      return cb null, _.object( names, results )

  # this will fetch the list of key names and value name for a given
  # granularity. The first value will be used in the redis key for the
  # things to update and the second is the key name of the hash. E.g.
  #
  # value1 = {
  #   value2: 20
  # }
  getKeyValueTimestamps: ( granularity ) ->
    { value, redis_ttl } = @constructor.granularities[granularity]

    return [
      @roundedTimestamp( redis_ttl ), # the redis key name
      @roundedTimestamp( value ),     # the key for the hash at the above key
    ]

  # Helper function to format timestamp in seconds. Defaults to curent
  # time
  toSeconds: ( ts=Date.now() ) -> Math.floor( ts / 1000 )

  # get the nearest point in time that PRECISION will fit into cleanly
  roundedTimestamp: ( precision, ts=@toSeconds() ) ->
    return Math.floor( ts / precision ) * precision

  # for each of the granularities run SETTER against the times
  _setHashValues: ( name, setter, cb ) ->
    all = []

    for gran, props of @constructor.granularities
      do( gran, props ) =>
        [ rounded_ttl, rounded_ts ] = @getKeyValueTimestamps gran
        redis_key = [ name, gran, rounded_ttl ]

        all.push ( cb ) ->
          setter rounded_ttl, rounded_ts, redis_key, props, cb

    return async.series all, cb

class exports.StatCounters extends Stat
  @instantiateOnStartup = true
  @smallKeyName         = "cntr"

  # returns the names of all of the keys that have been used for the
  # counters so far
  getAllCounterNames: ( cb ) ->
    @hkeys [ "meta", "counter-names" ], cb

  logCounter: ( multi, name, cb ) ->
    # we store the timestamp against all possible names just so that
    # we can tidy them up later (we can't use expire on hash values)
    multi.hset [ "meta", "counter-names" ], name, @toSeconds()

    setter = ( rounded_ttl, rounded_ts, redis_key, props, cb ) ->
      # increment the value and then set its ttl
      multi.hincrby redis_key, rounded_ts, 1
      multi.expireat redis_key, ( rounded_ttl + props.value )

      return cb null

    @_setHashValues name, setter, ( err ) ->
      return cb err if err
      return cb null, multi

class exports.StatTimers extends Stat
  @instantiateOnStartup = true
  @smallKeyName         = "timing"

  _getCurrentValues: ( redis_key, rounded_ts, cb ) ->
    multi = @multi()

    multi.hget redis_key, rounded_ts
    multi.hget redis_key, "#{ rounded_ts }-count"

    multi.exec ( err, [ values, count ] ) ->
      return cb err if err
      return cb null, JSON.parse( values ), parseInt( count ) if values
      return cb null, null, 0

  _getNewValues: ( timespan, min, max, average, count ) ->
    new_avg = ( ( ( average * count ) + timespan ) / ( count + 1 ) )
    new_min = if timespan < min then timespan else min
    new_max = if timespan > max then timespan else max

    # the / 1 hack is to convert the avg to a number
    return [ new_min, new_max, ( new_avg.toFixed( 2 ) / 1 ) ]

  # our values are JSON so we need to parse them on the way out
  _outputValueFilter: JSON.parse

  logTiming: ( multi, name, timespan, cb ) ->
    # store the name of the timer
    multi.hset [ "meta", "timer-names" ], name, @toSeconds()

    setter = ( rounded_ttl, rounded_ts, redis_key, props, cb ) =>
      @_getCurrentValues redis_key, rounded_ts, ( err, values, count ) =>
        return cb err if err

        # if we haven't stored in this section before then the new
        # values /are/ the min, max, avg and count is 1
        new_values = if not values?
          virgin_values = [ timespan, timespan, timespan ]
        else
          @_getNewValues timespan, values..., count

        # set the new values
        multi.hset redis_key, rounded_ts, JSON.stringify( new_values )

        # increment the count. We don't store this in the above
        # structure because we need it to be atomic
        multi.hincrby redis_key, "#{ rounded_ts }-count", 1

        # don't have it around forever
        multi.expireat redis_key, ( rounded_ttl + props.value )

        return cb null, new_values

    @_setHashValues name, setter, ( err ) ->
      return cb err if err
      return cb null, multi
