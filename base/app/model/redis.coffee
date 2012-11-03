async = require "async"
_ = require "underscore"
validate = require "../../lib/validate"
events = require "events"

redis = require "redis"

class Redis
  constructor: ( @application ) ->
    env = @application.constructor.env
    name = @constructor.smallKeyName or @constructor.name.toLowerCase()

    @ee = new events.EventEmitter()

    @ns = "gk:#{ env }:#{ name }"

  validate: ( details, cb ) ->
    validate @constructor.structure, details, cb

  create: ( id, details, cb ) ->
    @validate details, ( err, instance ) =>
      return cb err if err

      multi = @multi()

      details.createdAt = new Date().getTime()

      # first create the object
      multi.hmset id, instance

      # then add it to its list so that we can do range queries on it
      # later.
      multi.rpush "all", id

      multi.exec ( err, results ) ->
        return cb err if err

        cb null, details

  range: ( start, stop, cb ) ->
    @lrange "all", start, stop, cb

  find: ( key, cb ) ->
    @hgetall key, ( err, details ) ->
      return cb err, null if err
      return cb null, null unless details and _.size details
      return cb null, details

  multi: ( args ) ->
    return new RedisMulti( @ns, @application.redisClient, args )

  getKey: ( parts ) ->
    key = [ @ns ]
    key = key.concat parts

    return key.join ":"

  # Clear the keys associated with this model (taking into account the
  # namespace). It's for tests, not for use in production code.
  flush: ( cb ) ->
    multi = @application.redisClient.multi()

    # loop over all of the keys deleting them one by one :/
    @keys [ "*" ], ( err, keys ) ->
      return cb err if err

      for key in keys
        multi.del key, ( err, res ) ->
          return cb err if err

      multi.exec cb

  minuteString: ( date=new Date() ) =>
    return "#{ @hourString date }:#{ date.getMinutes() }"

  hourString: ( date=new Date() ) =>
    return "#{ @dayString date } #{ date.getHours() }"

  dayString: ( date=new Date() ) =>
    return "#{ @monthString date }-#{ date.getDate() }"

  monthString: ( date=new Date() ) =>
    return "#{ @yearString date }-#{ date.getMonth() + 1 }"

  yearString: ( date=new Date() ) =>
    return "#{ date.getFullYear() }"

  getValidationDocs: ( ) ->
    strings = for field, details of @constructor.structure.properties
      out = "* #{field}: "

      out += "(default: #{ details.default }) " if details.default
      out += "#{ details.docs or 'undocumented.'}"

    strings.join "\n"

class RedisMulti extends redis.Multi
  constructor: ( @ns, client, args ) ->
    @ee = new events.EventEmitter()

    super client, args

  getKey: Redis::getKey

# adding a command here will make it usable in Redis and RedisMulti
redisCommands = {
  "hset": "write"
  "hget": "read"
  "hmset": "write"
  "hincrby": "write"
  "hgetall": "read"
  "hexists": "read"
  "expire": "read"
  "set": "write"
  "get": "read"
  "incr": "write"
  "decr": "write"
  "del": "write"
  "keys": "read"
  "ttl": "write"
  "setex": "write"
  "sadd": "write"
  "smembers": "read"
  "scard": "read"
  "linsert": "write"
  "lrange": "read"
  "rpush": "write"
  "lpush": "write"
}

# build up the redis multi commands
for command, access of redisCommands
  do ( command, access ) ->
    # make sure we don't try to add something that doesn't exist
    if not RedisMulti.__super__[ command ]?
      throw new Error "No such redis commmand '#{ command }'"

    RedisMulti::[ command ] = ( key, args... ) ->
      full_key = @getKey( key )

      @ee.emit access, command, key, full_key
      RedisMulti.__super__[ command ].apply @, [ full_key, args... ]

    # Redis just offloads to the attached redis client. Perhaps we
    # should inherit from redis as RedisMulti does
    Redis::[ command ] = ( key, args... ) ->
      full_key = @getKey( key )

      @ee.emit access, command, key, full_key
      @application.redisClient[ command ]( full_key, args... )

exports.Redis = Redis
