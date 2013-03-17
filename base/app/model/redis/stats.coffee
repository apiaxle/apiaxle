# Store and access real time hits per second
async   = require "async"
_       = require "underscore"
{Redis} = require "../redis"

class exports.Stats extends Redis
  @instantiateOnStartup = true
  @smallKeyName         = "stats"

  @granulatities =
    seconds:
      size:   3600 # Amount of values stored in each hash, used for ts rounding
      ttl:    7200 # Keys live twice as long to handle overlap
      factor: 1    # Granularity, in seconds of the ts used for hash keys

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

  recordHit: ( db_key, cb ) ->
    multi = @multi()

    for gran, properties of Stats.granulatities
      tsround = @getRoundedTimestamp null, properties.size

      temp_key = _.clone db_key
      temp_key.push gran
      temp_key.push tsround
      # Hash keys are stored at second
      ts = @getSecondsTimestamp() * properties.factor
      multi.hincrby temp_key, ts, 1
      multi.expireat temp_key, tsround + properties.ttl

    multi.exec cb

  # Get a single response code for a key or api stat
  get: ( db_key, gran, from, to, cb) ->
    # TODO: fetch codes from redis
    properties = Stats.granulatities[gran]

    from = @getSecondsTimestamp from * properties.factor
    to   = @getSecondsTimestamp to * properties.factor

    # Check if in range
    if from >  to  or from < @getMinFrom gran
      console.log "Error: Invalid from time"
      cb {error: "Invalid from time"}, []
      return

    multi = @multi()
    ts = from
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
    properties = Stats.granulatities[gran]
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
        all.push ( cb ) => @recordHit db_key, cb

    async.series all, cb
