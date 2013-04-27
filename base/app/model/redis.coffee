async = require "async"
_ = require "lodash"
events = require "events"
redis = require "redis"

redisredisdebug = require( "debug" )( "aa:redis" )
redismultidebug = require( "debug" )( "aa:redis:multi" )

{ validate } = require "scarf"
{ ValidationError, KeyNotFoundError } = require "../../lib/error"

class Redis
  constructor: ( @app ) ->
    env =  @app.options.env
    name = @constructor.smallKeyName or @constructor.name.toLowerCase()

    @base_key = "gk:#{ env }"
    @ns = "#{ @base_key }:#{ name }"

  validate: ( details, cb ) ->
    validate @constructor.structure, details, true, ( err, with_defaults ) ->
      return cb err, with_defaults

  callConstructor: ( ) ->
    return @constructor.__super__.create.apply this, arguments

  update: ( id, details, cb ) ->
    redisdebug "update '#{ id }'"
    @find [ id ], ( err, results ) =>
      if not results[id]
        return cb new Error "Failed to update, can't find '#{ id }'."

      old = _.clone results[id].data

      # merge the new and old details
      merged_data = _.extend results[id].data, details

      @create id, merged_data, ( err ) =>
        return cb err if err
        return cb null, merged_data, old

  delete: ( id, cb ) ->
    redisdebug "update '#{ id }'"
    @find [ id ], ( err, results ) =>
      return cb new Error "'#{ id }' not found." if not results[id]

      id = @escapeId id

      multi = @multi()
      multi.del id
      multi.lrem "meta:all", 0, id
      multi.exec cb

  create: ( id, details, cb ) ->
    redisdebug "create '#{ id }'"
    @find [ id ], ( err, results ) =>
      return cb err if err

      update = results[id]?

      @validate details, ( err, instance ) =>
        return cb new ValidationError err.message if err

        # need to escape the key so that people don't use colons and
        # trick redis into overwrting other keys
        id = @escapeId id

        multi = @multi()

        # let users know what happened, when
        if update
          instance.updatedAt = Date.now()
          instance.createdAt = results[id].data.createdAt
        else
          instance.createdAt = Date.now()

        # first create the object
        multi.hmset id, instance

        # then add it to its list so that we can do range queries on it
        # later (if we're not doing an update)
        multi.rpush "meta:all", id unless update

        multi.exec ( err, results ) =>
          return cb err if err

          # no data means no object
          return cb null, null unless results

          # construct a new return object (see @returns on the factory
          # base class)
          if @constructor.returns?
            return cb null, new @constructor.returns( @app, id, instance )

          # no returns object, just throw back the data
          return cb null, instance

  range: ( start, stop, cb ) ->
    @lrange "meta:all", start, stop, cb

  # escape the id so that people can't sneak a colon in and do
  # something like modify metadata
  escapeId: ( id ) ->
    return id.replace( /([:])/g, "\\:" )

  _convertData: ( id, data ) =>
    return null unless data

    for key, val of data
      continue if not val?

      # find out what type we expect
      suggested_type = @constructor.structure.properties[ key ]?.type

      # convert int if need be
      if suggested_type and suggested_type is "integer"
        data[ key ] = parseInt( val )

      if suggested_type and suggested_type is "boolean"
        data[ key ] = ( val is "true" )

    # its created as a special model
    if @constructor.returns?
      return new @constructor.returns @app, id, data

    return data

  find: ( ids, cb ) ->
    redisredisdebug "find '#{ ids }'"
    # fetch all of the hits from redis
    multi = @multi()
    for id in ids
      multi.hgetall @escapeId( id )

    multi.exec ( err, results ) =>
      return cb err if err

      # update types to match
      converted = ( @_convertData( id, results[index] ) for index, id of ids )
      return cb null, _.object( ids, converted )

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

  # friendlier hexists (returns a bool rather than an int)
  fHexists: ( key, field, cb ) ->
    @hexists key, field, ( err, result ) ->
      return cb err if err
      return cb null, ( result is 1 )

class RedisMulti extends redis.Multi
  constructor: ( @ns, client, args ) -> super client, args
  getKey: Redis::getKey

class Model extends Redis
  constructor: ( @app, @id, @data ) ->
    super @app

  update: ( data, cb ) ->
    @app.model( @constructor.factory ).update @id, data, cb

  delete: ( cb ) ->
    @app.model( @constructor.factory ).delete @id, cb

# Used to extend something that can 'hold' keys (like an API or a
# keyring).
class KeyContainerModel extends Model
  delete: ( cb ) ->
    @llen "#{ @id }:keys", ( err, count ) =>
      return cb err if err

      # no need to unlink anything
      if parseInt count < 1
        return KeyContainerModel.__super__.delete.apply this, [ cb ]

      @getKeys 0, count - 1, ( err, keys ) =>
        return cb err if err

        # make sure we unlink all of the keys
        unlink_keys = []
        for key in keys
          do( key ) =>
            unlink_keys.push ( cb ) =>
              @unlinkKeyById key, cb

        async.parallel unlink_keys, ( err, results ) =>
          return cb err if err
          return KeyContainerModel.__super__.delete.apply this, [ cb ]

  linkKey: ( key, cb ) =>
    @app.model( "keyfactory" ).find [ key ], ( err, results ) =>
      return cb err if err

      if not results[key]
        return cb new KeyNotFoundError "#{ key } doesn't exist."

      results[key][ @constructor.reverseLinkFunction ] @id, ( err ) =>
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
            return cb null, results[key]

  unlinkKey: ( dbKey, cb ) ->
    # the key needs to know it's being disassociated with the API
    dbKey[ @constructor.reverseUnlinkFunction ] @id, ( err ) =>
      return cb err if err

      multi = @multi()

      # hopefully only one
      multi.lrem "#{ @id }:keys", 1, dbKey.id
      multi.hdel "#{ @id }:keys-lookup", dbKey.id

      multi.exec ( err ) ->
        return cb err if err
        return cb null, dbKey

  unlinkKeyById: ( keyName, cb ) ->
    @app.model( "keyfactory" ).find [ keyName ], ( err, results ) =>
      return cb err if err

      if not results[keyName]
        return cb new KeyNotFoundError "#{ keyName } doesn't exist."

      return @unlinkKey results[keyName], cb

  getKeys: ( start, stop, cb ) ->
    @lrange "#{ @id }:keys", start, stop, cb

  supportsKey: ( key, cb ) ->
    @fHexists "#{ @id }:keys-lookup", key, ( err, exists ) ->
      return cb err if err
      return cb null, exists

redisCommands = [
  "hset",
  "hget",
  "hdel",
  "hmset",
  "hincrby",
  "hgetall",
  "hexists",
  "exists",
  "expire",
  "expireat",
  "set",
  "get",
  "incr",
  "decr",
  "del",
  "keys",
  "ttl",
  "setex",
  "sadd",
  "hkeys",
  "smembers",
  "scard",
  "linsert",
  "lrange",
  "lrem",
  "llen",
  "rpush",
  "lpush",
  "zadd",
  "zrem",
  "zincrby",
  "zcard",
  "zrangebyscore"
]

# build up the redis multi commands
for command in redisCommands
  do ( command ) ->
    # make sure we don't try to add something that doesn't exist
    if not RedisMulti.__super__[ command ]?
      throw new Error "No such redis commmand '#{ command }'"

    RedisMulti::[ command ] = ( key, args... ) ->
      full_key = @getKey( key )

      redismultidebug "RedisMulti '#{ command }' on '#{ key }'"
      RedisMulti.__super__[ command ].apply this, [ full_key, args... ]

    # Redis just offloads to the attached redis client. Perhaps we
    # should inherit from redis as RedisMulti does
    Redis::[ command ] = ( key, args... ) ->
      full_key = @getKey( key )

      redisredisdebug "Redis '#{ command }' on '#{ key }'"
      @app.redisClient[ command ]( full_key, args... )

exports.Redis = Redis
exports.Model = Model
exports.KeyContainerModel = KeyContainerModel
