# Store and access real time hits per second
_ = require "lodash"
async = require "async"
debug = require( "debug" )( "aa:stats" )

# a bunch of constants to make things more readable
tconst = require "../../../lib/time_constants"

{ Redis } = require "../redis"

class exports.ArbStats extends Redis
  @instantiateOnStartup = true
  @smallKeyName         = "arb"

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

  # get the counter values. Args are:
  #  * names (array) - the name of the stat to fetch
  #  * granularity - the name of the granularity results are for.
  getCounterValues: ( names, gran, cb ) ->
    if not names or names.length is 0
      return cb Error "getCounterValues requires a list of names."

    if gran not in @gran_names
      return cb Error "Granularity must be one of #{ @gran_names.join(', ') }"

    multi = @multi()
    for name in names
      [ roundedTtl, roundedValue ] = @getKeyValueTimestamps gran
      redis_key = [ name, gran, roundedTtl ]

      # grab them from redis
      multi.hgetall redis_key

    multi.exec ( err, results ) ->
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
