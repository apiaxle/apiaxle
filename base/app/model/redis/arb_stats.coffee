# Store and access real time hits per second
_ = require "lodash"
async = require "async"
debug = require( "debug" )( "aa:stats" )

# a bunch of constants to make things more readable
tconst = require "../../../lib/time_constants"

{ Redis } = require "../redis"

class exports.StatCounters extends Redis
  @instantiateOnStartup = true
  @smallKeyName         = "cntr"

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

  constructor: ( args... ) ->
    # denormalise the keys above so that we can access them quickly
    # later
    @gran_names = _.keys @constructor.granularities

    super args...

  # Helper function to format timestamp in seconds. Defaults to curent
  # time
  toSeconds: ( ts=Date.now() ) -> Math.floor( ts / 1000 )

  # get the nearest point in time that PRECISION will fit into cleanly
  roundedTimestamp: ( precision, ts=@toSeconds() ) ->
    return Math.floor( ts / precision ) * precision

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

  # returns the names of all of the keys that have been used for the
  # counters so far
  getAllCounterNames: ( cb ) ->
    @hkeys [ "meta", "counter-names" ], cb

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

    [ roundedTtl, roundedValue ] = @getKeyValueTimestamps gran

    # collect the keys we want
    wantedTs = @_getValidTimeRange gran, from, to

    all = []
    for name in names
      do( name ) =>
        all.push ( cb ) =>
          multi = @multi()

          redis_key = [ name, gran, roundedTtl ]

          # for each wanted timestamp, collect the values
          multi.hget( redis_key, hashKey ) for hashKey in wantedTs

          multi.exec ( err, results ) ->
            return cb err if err
            return cb null, _.pick( _.object( wantedTs, results ), ( v ) -> v? )

    async.parallel all, ( err, results ) ->
      return cb err if err
      return cb null, _.object( names, results )

  logCounter: ( multi, name, cb ) ->
    # we store the timestamp against all possible names just so that
    # we can tidy them up later (we can't use expire on hash values)
    multi.hset [ "meta", "counter-names" ], name, @toSeconds()

    for gran, props of @constructor.granularities
      [ roundedTtl, roundedValue ] = @getKeyValueTimestamps gran

      redis_key = [ name, gran, roundedTtl ]

      # increment the value and then set its ttl
      multi.hincrby redis_key, roundedValue, 1
      multi.expireat redis_key, ( roundedTtl + props.value )

    return cb null, multi
