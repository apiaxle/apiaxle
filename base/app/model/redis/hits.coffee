# Store and access real time hits per second
async = require "async"
{ Redis } = require "../redis"

class exports.Hits extends Redis
  @instantiateOnStartup = true
  @smallKeyName         = "hits"
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
    tsmin  = @getRoundedTimestamp null, 60
    db_key.push tsmin

    @exists db_key, ( err, res ) =>
      ts    = Math.floor( (new Date()).getTime()/1000 )
      # Key already exists, add or inc this second
      # Otherwise we also need to set the expiry
      if res
        @hincrby db_key, ts, 1, cb
      else
        @hincrby db_key, ts, 1, ( err, res ) =>
          @expire  db_key, Hits.ttl, cb

  hit: ( api, key, response, cb ) ->
    db_keys = [
      [ "api", api, "minute" ],
      [ "key", key, "minute" ]
    ]

    all = []
    for key in db_keys
      do( key ) =>
        all.push ( cb ) => @recordHit key, cb

    async.series all, cb

  # Return the hits for the most recent second
  # Zero if none found
  getRealTime: ( type, id, cb ) ->
    tsmin  = @getRoundedTimestamp null, 60
    tssec  = @getRoundedTimestamp null
    db_key = [ type, id, "minute", tsmin ]

    @hget db_key, tssec, ( err, details ) =>
      details = 0 unless details
      cb err, details

  getCurrentMinute: ( type, id, cb ) ->
    tsmin  = @getRoundedTimestamp null, 60
    db_key = [ type, id, "minute", tsmin ]

    @hgetall db_key, ( err, details ) =>
      cb err, details
