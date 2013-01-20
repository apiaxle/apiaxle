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
  getRoundedTimestamp: ( precision = 1 ) ->
    ts    = Math.floor( (new Date()).getTime()/1000 )
    ts    = Math.ceil( ts / precision ) * precision
    return ts

  hit: ( api, key, response, cb ) ->
    # Get Redis Key
    tsmin  = @getRoundedTimestamp 60
    db_key = [ "api", api, "minute", response, tsmin ]

    @exists db_key, ( err, res ) =>
      ts    = Math.floor( (new Date()).getTime()/1000 )

      # Key already exists, add or inc this second
      # Otherwise we also need to set the expiry
      if res
        @hincrby db_key, ts, 1, cb
      else
        @hincrby db_key, ts, 1, ( err, res ) =>
          @expire  db_key, Stats.ttl, cb
