_ = require "underscore"

{ Redis, Model } = require "../redis"
{ ValidationError } = require "../../../lib/error"

validationEnv = require( "schema" )( "keyEnv" )

class Key extends Model

class exports.KeyFactory extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "key"
  @returns      = Key

  @structure = validationEnv.Schema.create
    type: "object"
    additionalProperties: false
    properties:
      sharedSecret:
        type: "string"
        optional: true
        docs: "A shared secret which is used when signing a call to the api."
      qpd:
        type: "integer"
        default: 172800
        docs: "Number of queries that can be called per day. Set to `-1` for no limit."
      qps:
        type: "integer"
        default: 2
        docs: "Number of queries that can be called per second. Set to `-1` for no limit."
      forApi:
        required: true
        type: "string"
        docs: "Name of the Api that this key belongs to."

  create: ( id, details, cb ) ->
    # if there isn't a forApi field then `super` will take care of
    # that
    if not details?.forApi?
      return super

    @app.model( "apiFactory" ).find details.forApi, ( err, api ) =>
      return cb err if err

      if not api
        return cb new ValidationError "API '#{ details.forApi }' doesn't exist."

      # Save the key
      api.addKey id, ( err ) =>
        return cb err if err

        # why won't coffeescript just let me call super here?
        return @constructor.__super__.create.apply @, [ id, details, cb ]
