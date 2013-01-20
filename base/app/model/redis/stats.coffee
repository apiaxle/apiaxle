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
    # Get key
    tsmin = @getRoundedTimestamp 60
    key   = [ "api", api, "minute", response, tsmin ]

    @exists key, ( err, res ) =>
      ts    = Math.floor( (new Date()).getTime()/1000 )
      multi = @multi()

      # Key already exists, add or inc this second
      # Otherwise we also need to set the expiry
      if res
        multi.hincrby key, ts, 1
        multi.exec cb
      else
        @hincrby key, ts, 1, ( err, res ) =>
          @expire  key, Stats.ttl, cb
