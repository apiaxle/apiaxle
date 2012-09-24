_ = require "underscore"

{ Redis } = require "../redis"
{ ValidationError } = require "../../../lib/error"

validationEnv = require( "schema" )( "apiKeyEnv" )

class exports.ApiKey extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "key"

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

  create: ( name, details, cb ) ->
    # if there isn't a forApi field then `super` will take care of
    # that
    if details?.forApi?
      @application.model( "api" ).find details.forApi, ( err, apiDetails ) =>
        return cb err if err

        if not apiDetails
          return cb new ValidationError "API '#{ details.forApi }' doesn't exist."

        # Save the key
        @application.model("api").add_key details.forApi, name

        # why won't coffeescript just let me call super here?
        ApiKey.__super__.create.apply @, [ name, details, cb ]
    else
      super
