async = require "async"
_ = require "underscore"
validate = require "../../lib/validate"
events = require "events"

redis = require "redis"

class Redis
  constructor: ( @app ) ->
    env =  @app.constructor.env
    name = @constructor.smallKeyName or @constructor.name.toLowerCase()

    @base_key = "gk:#{ env }"

    @ee = new events.EventEmitter()
    @ns = "#{ @base_key }:#{ name }"

  validate: ( details, cb ) ->
    try
      return validate @constructor.structure, details, cb
    catch err
      return cb err, null

  create: ( id, details, cb ) ->
    @validate details, ( err, instance ) =>
      return cb err if err

      # need to escape the key so that people don't use colons and
      # trick redis into overwrting other keys
      id = @escapeId id

      multi = @multi()

      details.createdAt = new Date().getTime()

      # first create the object
      multi.hmset id, instance

      # then add it to its list so that we can do range queries on it
      # later.
      multi.rpush "meta:all", id

      multi.exec ( err, results ) =>
        return cb err if err

        # no data means no object
        return cb null, null unless results

        # construct a new return object (see @returns on the factory
        # base class)
        if @constructor.returns?
          return cb null, new @constructor.returns( @app, id, details )

        # no returns object, just throw back the data
        return cb null, details

  range: ( start, stop, cb ) ->
    @lrange "meta:all", start, stop, cb

  # escape the id so that people can't sneak a colon in and do
  # something like modify metadata
  escapeId: ( id ) ->
    return id.replace( /([:])/g, "\\:" )

  find: ( id, cb ) ->
    id = @escapeId id

    @hgetall id, ( err, details ) =>
      return cb err, null if err
      return cb null, null unless details and _.size details

      if @constructor.returns?
        return cb null, new @constructor.returns @app, id, details

      return cb null, details

  multi: ( args ) ->
    return new RedisMulti( @ns, @app.redisClient, args )

  getKey: ( parts ) ->
    key = [ @ns ]
    key = key.concat parts

    return key.join ":"

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

class Model extends Redis
  constructor: ( @app, @id, @data ) ->
    super @app

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
  "lrem": "write"
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
      @app.redisClient[ command ]( full_key, args... )

exports.Redis = Redis
exports.Model = Model
