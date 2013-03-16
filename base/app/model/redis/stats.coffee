# Store and access real time hits per second
async   = require "async"
{Redis} = require "../redis"

class exports.Stats extends Redis
  @instantiateOnStartup = true
  @smallKeyName         = "stats"

  @granulatities =
    seconds:
      ttl:    120
      factor: 60  # Value to divide timestamp for rounding

  # Get a timestamp rounded to the supplied precision
  # 1 = 1 second
  getRoundedTimestamp: ( ts, precision = 1 ) ->
    if not ts
      ts    = Math.floor( (new Date()).getTime()/1000 )
    ts = Math.floor( ts / precision ) * precision
    return ts

  recordHit: ( db_key, cb ) ->
    multi = @multi()

    for i, gran in Stats.granulatities
      tsround = @getRoundedTimestamp null, gran.factor

      temp_key = db_key.splice(0)
      temp_key.push granularity
      temp_key.push tsround
      ts = Math.floor( (new Date()).getTime()/1000 )

      multi.hincrby temp_key, ts, 1
      multi.expireat temp_key, tsmin + gran.ttl

    multi.exec cb

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
