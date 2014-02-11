# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
# Store and access real time hits per second
async   = require "async"
_       = require "lodash"

{Redis} = require "../redis"

class exports.Stats extends Redis
  @instantiateOnStartup = true
  @smallKeyName         = "stats2"

  # A list of granularities at which we store statistics. For each of
  # them the following fields are required:
  #
  # * size - amount of values stored in each hash, used for ts
  #   rounding.
  # * ttl - how long the keys will live in redis.
  # * factor - granularity in seconds. This value is used to round off
  #   the timestamps
  @granularities =
    second: # kept for 1 hour
      size:   3600
      ttl:    7200
      factor: 1

    minute: # Available for 24 hours
      size:   1440
      ttl:    172800
      factor: 60

     hour: # Available for 7 days
       size:   168
       ttl:    1209600
       factor: 3600

     day: # Available for 24 months
       size:   365
       ttl:    63113880
       factor: 86400

  # Helper function to format timestamp in seconds
  # Defaults to curent time
  getSecondsTimestamp: ( ts=Date.now() ) ->
    return Math.floor( ts / 1000 )

  # Get a timestamp rounded to the supplied precision
  # Precision is typically the size of the key in question
  getRoundedTimestamp: ( ts=@getSecondsTimestamp(), precision=1 ) ->
    return Math.floor( ts / precision ) * precision

  getFactoredTimestamp: ( ts_seconds=@getSecondsTimestamp(), factor ) ->
    return Math.floor( ts_seconds / factor ) * factor

  getPossibleResponseTypes: ( db_key, cb ) ->
    return @smembers db_key.concat([ "response-types" ]), cb

  # record the score for thing at various granularities
  recordScore: ( multi, time, db_key, thing ) ->
    for gran, properties of Stats.granularities
      tsround = @getRoundedTimestamp time, properties.factor
      temp_key = db_key.concat [ gran, "score" ]

      # hash keys are stored at second
      ts = @getFactoredTimestamp null, properties.factor
      multi.zincrby temp_key, 1, thing
      multi.expireat temp_key, tsround + properties.factor

    return multi

  recordHit: ( multi, time, [ db_key..., axle_type ] ) ->
    multi.sadd db_key.concat([ "response-types" ]), axle_type

    for gran, properties of Stats.granularities
      tsround = @getRoundedTimestamp time, ( properties.size * properties.factor )

      temp_key = db_key.concat [ axle_type, gran, tsround ]

      # hash keys are stored at second
      ts = @getFactoredTimestamp null, properties.factor
      multi.hincrby temp_key, ts, 1
      multi.expireat temp_key, tsround + properties.ttl

    return multi

  # [ 'api', 'days', 'score' ] 'facebook'
  getScores: ( db_key, gran, cb ) ->
    temp_key = db_key.concat [ gran, "score" ]

    return @zrevrangeOpt temp_key, [ 0, 100, "WITHSCORES" ], ( err, scores ) ->
      all = {}

      # zip up the array into an object
      while scores.length > 0
        all[ scores.shift() ] = parseInt scores.shift()

      return cb err if err
      return cb null, all

  # Get all response codes for a particular stats entry
  getAll: ( db_key, gran, from, to, cb ) ->
    @getPossibleResponseTypes db_key, ( err, codes ) =>
      return cb err if err

      all = []
      for code in codes
        do( code ) =>
          all.push ( cb ) =>
            @get db_key.concat([ code ]), gran, from, to, cb

      async.series all, ( err, res ) =>
        return cb err if err

        results = {}
        for code, idx in codes
          for ts, amount of res[idx]
            results[ts] ||= {}
            results[ts][code] = amount

        return cb null, results

  # Get a single response code for a key or api stat
  # from, to should be int, seconds
  get: ( db_key, gran, from, to, cb ) ->
    properties = Stats.granularities[gran]

    if not properties
      return cb new Error "Invalid granularity"

    from = @getFactoredTimestamp( from, properties.factor )
    to   = @getFactoredTimestamp( to, properties.factor )

    # Check if in range
    if from > to
      msg = "Invalid from time from (#{ from }) is more than to (#{ to })"
      return cb new Error msg

    if from < ( min = @getMinFrom gran )
      msg = "#{ min } is the earliest time available for the '#{ gran }' granularity"
      return cb new Error msg

    multi = @multi()
    ts    = from

    while ts <= to
      tsround = @getRoundedTimestamp ts, ( properties.factor * properties.size )

      temp_key = _.clone db_key
      temp_key.push gran
      temp_key.push tsround

      multi.hget temp_key, ts
      ts += properties.factor

    # we need to format the results into an object ts => hits
    multi.exec ( err, results ) =>
      return cb err if err

      ts = from
      i  = 0
      data = {}
      while ts <= to
        if res = results[i]
          data[ts] = parseInt res

        ts += properties.factor
        i += 1

      return cb null, data

  getMinFrom: ( gran ) ->
    properties = Stats.granularities[gran]
    min = @getRoundedTimestamp null, ( properties.factor * properties.size )

    # subtract ttl from the most recent rounded timestamp to allow for
    # overlap
    return ( min - properties.ttl )

  hit: ( api, key, keyrings, cached, code, time, cb ) ->
    multi = @multi()

    @recordHit multi, time, [ "api", api, cached, code ]
    @recordHit multi, time, [ "key", key, cached, code ]
    @recordHit multi, time, [ "key-api", key, api, cached, code ]

    @recordScore multi, time, [ "api" ], api
    @recordScore multi, time, [ "key" ], key
    @recordScore multi, time, [ "key-api", key ], api
    @recordScore multi, time, [ "api-key", api ], key

    # record the keyring stats too
    for keyring in keyrings
      @recordHit multi, time, [ "keyring", keyring, cached, code ]
      @recordHit multi, time, [ "keyring-api", keyring, api, cached, code ]
      @recordHit multi, time, [ "keyring-key", keyring, key, cached, code ]

      @recordScore multi, time, [ "keyring" ], keyring
      @recordScore multi, time, [ "keyring-api", keyring ], api
      @recordScore multi, time, [ "keyring-key", keyring ], key

    return multi.exec cb
