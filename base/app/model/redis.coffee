async = require "async"
_ = require "underscore"
validate = require "../../lib/validate"
events = require "events"
redis = require "redis"

{ KeyNotFoundError } = require "../../lib/error"

class Redis
  constructor: ( @app ) ->
    env =  @app.constructor.env
    name = @constructor.smallKeyName or @constructor.name.toLowerCase()

    @base_key = "gk:#{ env }"

    @ee = new events.EventEmitter()
    @ns = "#{ @base_key }:#{ name }"

  validate: ( details, cb ) ->
    return validate @constructor.structure, details, ( err ) ->
      return cb err, details

  callConstructor: ( id, details, cb ) ->
    return @constructor.__super__.create.apply @, [ id, details, cb ]

  update: ( id, details, cb ) ->
    @find id, ( err, dbObj ) ->
      if not dbObj
        return cb new Error "Failed to update, can't find '#{ id }'."

      # merge the new and old details
      merged_data = _.extend dbObj.data, details

      @create id, merged_data, cb

  delete: ( id, cb ) ->
    @find id, ( err, dbObj ) =>
      return cb new Error "'#{ id }' not found." if not dbObj

      id = @escapeId id

      multi = @multi()
      multi.del id
      multi.lrem "meta:all", 0, id
      multi.exec cb

  create: ( id, details, cb ) ->
    @find id, ( err, dbObj ) =>
      return cb err if err

      update = dbObj?

      @validate details, ( err, instance ) =>
        return cb err if err

        # need to escape the key so that people don't use colons and
        # trick redis into overwrting other keys
        id = @escapeId id

        multi = @multi()

        # let users know what happened, when
        if update
          details.updatedAt = new Date().getTime()
          details.createdAt = dbObj.data.createdAt
        else
          details.createdAt = new Date().getTime()

        # first create the object
        multi.hmset id, instance

        # then add it to its list so that we can do range queries on it
        # later (if we're not doing an update)
        if not update
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

      for key, val of details
        continue if not val?

        # find out what type we expect
        suggested_type = @constructor.structure.properties[ key ]?.type

        # convert int if need be
        if suggested_type and suggested_type is "integer"
          details[ key ] = parseInt( val )

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
      continue unless details.docs?

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

# Used to extend something that can 'hold' keys (like an API or a
# keyring).
class KeyContainerModel extends Model
  linkKey: ( key, cb ) =>
    @app.model( "keyFactory" ).find key, ( err, dbObj ) =>
      return cb err if err

      if not dbObj
        return cb new KeyNotFoundError "#{ key } doesn't exist."

      dbObj[ @constructor.reverseLinkFunction ] @id, ( err ) =>
        return cb err if err

        # add to the list of all keys if it's not already there
        @supportsKey key, ( err, is_already_added ) =>
          return cb err if err

          multi = @multi()

          # the list (if need be)
          if not is_already_added
            multi.lpush "#{ @id }:keys", key

          # and add to a quick lookup for the keys
          multi.hset "#{ @id }:keys-lookup", key, 1

          multi.exec ( err ) ->
            return cb err if err
            return cb null, dbObj

  unlinkKey: ( keyName, cb ) ->
    @app.model( "keyFactory" ).find keyName, ( err, dbObj ) =>
      return cb err if err

      if not dbObj
        return cb new KeyNotFoundError "#{ keyName } doesn't exist."

      dbObj[ @constructor.reverseUnlinkFunction ] keyName, ( err ) =>
        return cb err if err

        multi = @multi()

        # hopefully only one
        multi.lrem "#{ @id }:keys", 1, keyName
        multi.hdel "#{ @id }:keys-lookup", keyName

        multi.exec ( err ) ->
          return cb err if err
          return cb null, dbObj

  getKeys: ( start, stop, cb ) ->
    @lrange "#{ @id }:keys", start, stop, cb

  supportsKey: ( key, cb ) ->
    @hexists "#{ @id }:keys-lookup", key, ( err, exists ) ->
      return cb err if err

      if exists is 0
        return cb null, false

      return cb null, true

# adding a command here will make it usable in Redis and
# RedisMulti. The reason for the read/write attribute is so that when
# the emitter does its thing you can watch reads/writes/both
redisCommands = {
  "hset": "write"
  "hget": "read"
  "hdel": "write"
  "hmset": "write"
  "hincrby": "write"
  "hgetall": "read"
  "hexists": "read"
  "exists": "read"
  "expire": "write"
  "set": "write"
  "get": "read"
  "incr": "write"
  "decr": "write"
  "del": "write"
  "keys": "read"
  "ttl": "write"
  "setex": "write"
  "sadd": "write"
  "hkeys": "read"
  "smembers": "read"
  "scard":   "read"
  "linsert": "write"
  "lrange":  "read"
  "lrem":    "write"
  "rpush":   "write"
  "lpush":   "write"
  "zadd":    "write"
  "zrem":    "write"
  "zincrby": "write"
  "zcard":   "read"
  "zrangebyscore": "read"
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
exports.KeyContainerModel = KeyContainerModel
