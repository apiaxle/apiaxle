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
      @roundedTimestamp( redis_ttl ),
      @roundedTimestamp( value )
    ]

  logCounter: ( multi, name, cb ) ->
    # we store the timestamp against all possible names just so that
    # we can tidy them up later (we can't use expire on hash values)
    multi.hset [ "meta", "counter-names" ], name, @roundedTimestamp( 1 )

    output = {}

    for gran in _.keys @constructor.granularities
      roundedValues = @getKeyValueTimestamps gran
      output[gran] = roundedValues

    multi.exec ( err ) -> cb err, output
