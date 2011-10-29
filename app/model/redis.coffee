redis = require "redis"

class RedisMulti extends redis.Multi
  constructor: ( @ns, client, args ) ->
    super client, args

  getKey: ( parts ) ->
    key = [ @ns ]
    key = key.concat parts

    return key.join ":"

  set: ( key, args... ) ->
    super @getKey( key ), args...

  get: ( key, args... ) ->
    super @getKey( key ), args...

  decr: ( key, args... ) ->
    super @getKey( key ), args...

  incr: ( key, args... ) ->
    super @getKey( key ), args...

  ttl: ( key, args... ) ->
    super @getKey( key ), args...

  setex: ( key, args... ) ->
    super @getKey( key ), args...

class exports.Redis
  @commands = [
    "hmset"
    "hgetall"
    "hexists"
    "expire"
    "set"
    "get"
    "incr"
    "decr"
    "del"
    "keys"
    "ttl"
    "setex"
  ]

  constructor: ( @gatekeeper ) ->
    env = @gatekeeper.constructor.env
    name = @constructor.smallKeyName or @constructor.name.toLowerCase()

    @ns = "gk:#{ env }:#{ name }"

    # build up the commands in `commands`, making sure they use the
    # corrent namespace. Rather than a string for key they take an
    # array of strings which are joined later.
    for command in @constructor.commands
      do ( command ) =>
        @[ command ] = ( key, rest... ) =>
          @gatekeeper.redisClient[ command ]( @getKey( key ), rest... )

  multi: ( args ) ->
    return new RedisMulti( @ns, @gatekeeper.redisClient, args )

  getKey: ( parts ) ->
    key = [ @ns ]
    key = key.concat parts

    return key.join ":"

  # Clear the keys associated with this model (taking into account the
  # namespace). It's for tests, not for use in production code.
  flush: ( cb ) ->
    multi = @gatekeeper.redisClient.multi()

    # loop over all of the keys deleting them one by one :/
    @keys [ "*" ], ( err, keys ) ->
      return cb err if err

      for key in keys
        multi.del key, ( err, res ) ->
          return cb err if err

      multi.exec cb

  _hourString: ->
    now = new Date()
    return "#{ now.getFullYear()}#{ now.getMonth() }#{ now.getDay() }#{ now.getHours() }"

  _dayString: ->
    now = new Date()
    return "#{ now.getFullYear()}#{ now.getMonth() }#{ now.getDay() }"

  _monthString: ->
    now = new Date()
    return "#{ now.getFullYear()}#{ now.getMonth() }"

  _yearString: ->
    now = new Date()
    return "#{ now.getFullYear() }"