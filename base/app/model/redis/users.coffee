async = require "async"

{ Redis } = require "../redis"
{ ValidationError } = require "../../../lib/error"

validationEnv = require( "schema" )( "apiEnv" )

class exports.Users extends Redis
  @instantiateOnStartup = true

  @structure = validationEnv.Schema.create
    type: "object"
    additionalProperties: false
    properties:
      email:
        type: "string"
        required: true
        pattern: /.+?@.+?\..{2,5}$/

  addKey: ( userName, key, cb ) ->
    keyModel = @application.model "apiKey"

    @find userName, ( err, dbUser ) =>
      return cb err if err

      if not dbUser?
        return cb new ValidationError "User '#{ userName }' doesn't exist."

      keyModel.find key, ( err, dbKey ) =>
        return cb err if err

        if not dbKey?
          return cb new ValidationError "Key '#{ key }' doesn't exist."

        # add the user to the key
        keyModel.hset key, "owningUser", userName, ( err, value ) =>
          return cb err if err

          # add the key to a set of this user's keys
          return @sadd "#{userName}:keys", key, cb

  getKeys: ( userName, cb ) ->
    @smembers "#{userName}:keys", cb

  keyCount: ( userName, cb ) ->
    @scard "#{userName}:keys", cb
