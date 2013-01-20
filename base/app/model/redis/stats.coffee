# Store and access real time hits per second
async = require "async"
{ Redis } = require "../redis"

class exports.Stats extends Redis
  @instantiateOnStartup = true
  @smallKeyName         = "stats"
  # How long each minute of data will remain
  @ttl                  = 120

  # Get a timestamp rounded to the supplied precision
  # 1 = 1 second
  getRoundedTimestamp: ( ts, precision = 1 ) ->
    if not ts
      ts    = Math.floor( (new Date()).getTime()/1000 )
    ts    = Math.ceil( ts / precision ) * precision
    return ts

  recordHit: ( db_key, cb ) ->
    tsmin  = @getRoundedTimestamp 60
    db_key.push tsmin

    @exists db_key, ( err, res ) =>
      ts    = Math.floor( (new Date()).getTime()/1000 )
      # Key already exists, add or inc this second
      # Otherwise we also need to set the expiry
      if res
        @hincrby db_key, ts, 1, cb
      else
        @hincrby db_key, ts, 1, ( err, res ) =>
          @expire  db_key, Stats.ttl, cb

  hit: ( api, key, response, cb ) ->
    db_keys = [
      [ "api", api, "minute", response ],
      [ "key", key, "minute", response ]
    ]

    all = []
    for key in db_keys
      do( key ) =>
        all.push ( cb ) => @recordHit key, cb

    async.series all, cb

  getMinute: ( ts = null ) ->
    tsmin = @getRoundedTimestamp ts, 60
