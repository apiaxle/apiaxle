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

  recordHit: ( db_key, granularity, cb ) ->
    gran  = Stats.granulatities[granularity]
    tsmin = @getRoundedTimestamp null, gran.factor

    db_key.push granularity
    db_key.push tsmin

    ts = Math.floor( (new Date()).getTime()/1000 )
    @hincrby db_key,  ts, 1, (err, result) =>
      @ttl db_key, (err, res) =>
        if res < 0
          @expireat db_key, tsmin + gran.ttl
        cb err, result

  hit: ( api, key, response, cb ) ->
    db_keys = [
      [ "api", api ],
      [ "key", key ]
    ]

    all = []
    for key in db_keys
      do( key ) =>
        all.push ( cb ) => @recordHit key, "seconds", cb

    async.series all, cb
