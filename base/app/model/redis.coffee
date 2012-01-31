async = require "async"
_ = require "underscore"
validate = require "../../lib/validate"

redis = require "redis"

class Redis
  constructor: ( @application ) ->
    env = @application.constructor.env
    name = @constructor.smallKeyName or @constructor.name.toLowerCase()

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

      return cb null, null unless _.size( details )

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

  hourString: ( date=new Date() ) ->
    return "#{ date.getFullYear() }-#{ date.getMonth() + 1 }-#{ date.getDay() + 1 }#{ date.getHours() }"

  dayString: ( date=new Date() ) ->
    return "#{ date.getFullYear() }-#{ date.getMonth() + 1 }-#{ date.getDay() + 1 }"

  monthString: ( date=new Date() ) ->
    return "#{ date.getFullYear() }-#{ date.getMonth() + 1 }"

  yearString: ( date=new Date() ) ->
    return "#{ date.getFullYear() }"

  getValidationDocs: ( ) ->
    strings = for field, details of @constructor.structure.properties
      out = "* #{field} - "

      out += "(default: #{ details.default }) " if details.default
      out += "#{ details.docs or 'undocumented.'}"

    strings.join "\n"

class RedisMulti extends redis.Multi
  constructor: ( @ns, client, args ) ->
    super client, args

  getKey: Redis::getKey

# adding a command here will make it usable in Redis and RedisMulti
redisCommands = [
  "hset"
  "hget"
  "hmset"
  "hincrby"
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
  "sadd"
  "smembers"
  "scard"
  "linsert"
  "lrange"
  "rpush"
  "lpush"
]

# build up the redis multi commands
for command in redisCommands
  do ( command ) ->
    # make sure we don't try to add something that doesn't exist
    if not RedisMulti.__super__[ command ]?
      throw new Error "No such redis commmand '#{ command }'"

    RedisMulti::[ command ] = ( key, args... ) ->
      RedisMulti.__super__[ command ].apply @, [ @getKey( key ), args... ]

    # Redis just offloads to the attached redis client. Perhaps we
    # should inherit from redis as RedisMulti does
    Redis::[ command ] = ( key, args... ) ->
      @application.redisClient[ command ]( @getKey( key ), args... )

exports.Redis = Redis
