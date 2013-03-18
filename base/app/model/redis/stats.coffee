# Store and access real time hits per second
async   = require "async"
_       = require "underscore"
{Redis} = require "../redis"

class exports.Stats extends Redis
  @instantiateOnStartup = true
  @smallKeyName         = "stats"

  @granularities =
    seconds:       # Available for 1 hour
      size:   3600 # Amount of values stored in each hash, used for ts rounding
      ttl:    7200 # Keys live twice as long to handle overlap
      factor: 1    # Granularity, in seconds of the ts used for hash keys

    minutes:         # Available for 24 hours
      size:   1440   # Amount of values stored in each hash, used for ts rounding
      ttl:    172800 # Keys live twice as long to handle overlap
      factor: 60     # Granularity, in seconds of the ts used for hash keys

  # Helper function to format timestamp in seconds
  # Defaults to curent time
  getSecondsTimestamp: (ts) ->
    if not ts
      ts = (new Date()).getTime()
    return Math.floor( ts/1000 )

  # Get a timestamp rounded to the supplied precision
  # 1 = 1 second
  getRoundedTimestamp: ( ts, precision = 1 ) ->
    if not ts
      ts    = @getSecondsTimestamp()
    ts = Math.floor( ts / precision ) * precision
    return ts

  getFactoredTimestamp:(ts_seconds, factor) ->
    if not ts_seconds
      ts_seconds = @getSecondsTimestamp()
    ts = Math.floor(ts_seconds / factor) * factor

  getPossibleResponseTypes: ( db_key, cb ) ->
    return @smembers [ db_key[0], db_key[1], "all-response-types" ], cb

  recordHit: ( db_key, cb ) ->
    multi = @multi()
    multi.sadd [db_key[0], db_key[1], "all-response-types"], db_key[2]

    for gran, properties of Stats.granularities
      tsround = @getRoundedTimestamp null, properties.size

      temp_key = _.clone db_key
      temp_key.push gran
      temp_key.push tsround
      # Hash keys are stored at second
      ts = @getFactoredTimestamp(null, properties.factor)
      multi.hincrby temp_key, ts, 1
      multi.expireat temp_key, tsround + properties.ttl

    multi.exec cb

  # Get a single response code for a key or api stat
  # from, to should be int, seconds
  get: ( db_key, gran, from, to, cb) ->
    # TODO: fetch codes from redis
    properties = Stats.granularities[gran]

    from = @getFactoredTimestamp(from, properties.factor)
    to   = @getFactoredTimestamp(to, properties.factor)

    # Check if in range
    if from >  to  or from < @getMinFrom gran
      cb {error: "Invalid from time"}, null
      return

    multi = @multi()
    ts    = from
    while ts <= to
      tsround = @getRoundedTimestamp ts, properties.size

      temp_key = _.clone(db_key)
      temp_key.push gran
      temp_key.push tsround

      multi.hget temp_key, ts
      ts += properties.factor

    # We need to format the results into an object ts => hits
    # Also 0 pads
    multi.exec (err, results) =>
      ts = from
      i  = 0
      data = {}
      while ts <= to
        res = results[i]
        if not res
          res = 0
        data[ts] = res
        ts += properties.factor
        i += 1
      return cb err, data

  getMinFrom: (gran) ->
    properties = Stats.granularities[gran]
    now = @getSecondsTimestamp()
    # Subtract one for edge case of exactly on expiry time
    return (now - properties.size) - properties.factor

  hit: ( api, key, code, cb ) ->
    db_keys = [
      [ "api", api, code ],
      [ "key", key, code ]
    ]

    all = []
    for db_key in db_keys
      do( db_key ) =>
        all.push (cb) => @recordHit db_key, cb

    async.series all, cb
