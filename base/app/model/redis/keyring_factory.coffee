async = require "async"

{ Redis, Model } = require "../redis"
{ ValidationError } = require "../../../lib/error"

validationEnv = require( "schema" )( "apiEnv" )

class Keyring extends Model
  addKey: ( key_name, cb ) =>
    @application.model( "keyFactory" ).find key_name, ( err, key ) =>
      return cb err if err

      if not key
        return cb new ValidationError "Key #{ key_name } not found."

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
