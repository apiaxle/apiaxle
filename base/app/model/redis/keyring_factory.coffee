async = require "async"

{ Redis, Model } = require "../redis"
{ ValidationError } = require "../../../lib/error"

class Keyring extends Model
  delKey: ( key_name, cb ) ->
    @app.model( "keyFactory" ).find key_name, ( err, key ) =>
      return cb err if err

      if not key
        return cb new ValidationError "Key '#{ key_name }' not found."

      @lrem "#{ @id }:keys", 0, key_name, ( err ) ->
        return cb err if err
        return cb null, key

  linkKeys: ( key_names, cb ) =>
    all = []

    for key in key_names
      do( key ) =>
        all.push ( cb ) => @linkKey key, cb

    async.series all, cb

  linkKey: ( key_name, cb ) =>
    @app.model( "keyFactory" ).find key_name, ( err, key ) =>
      return cb err if err

      if not key
        return cb new ValidationError "Key '#{ key_name }' not found."

      @lpush "#{ @id }:keys", key_name, ( err ) ->
        return cb err, key

  getKeys: ( start, stop, cb ) ->
    @lrange "#{ @id }:keys", start, stop, cb

class exports.KeyringFactory extends Redis
  @instantiateOnStartup = true
  @returns = Keyring
  @structure =
    type: "object"
    additionalProperties: false
    properties:
      createdAt:
        type: "integer"
        optional: true
      updatedAt:
        type: "integer"
        optional: true
