async = require "async"

{ Redis, Model } = require "../redis"
{ ValidationError } = require "../../../lib/error"

validationEnv = require( "schema" )( "apiEnv" )

class Keyring extends Model
  delKey: ( key_name, cb ) ->
    @app.model( "keyFactory" ).find key_name, ( err, key ) =>
      return cb err if err

      if not key
        return cb new ValidationError "Key '#{ key_name }' not found."
    
      @lrem "#{ @id }:keys", 0, key_name, ( err ) ->
        return cb err if err

        return cb null, key

  addKeys: ( key_names, cb ) =>
    all = []

    for key in key_names
      do( key ) =>
        all.push ( cb ) => @addKey key, cb

    async.series all, cb

  addKey: ( key_name, cb ) =>
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
  @structure = validationEnv.Schema.create
    type: "object"
    additionalProperties: false
