_ = require "underscore"

{ Redis } = require "../redis"
{ ValidationError } = require "../../../lib/error"

class exports.ApiKey extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "key"

  @structure =
    type: "object"
    properties:
      qpd:
        type: "integer"
        default: 172800
      qps:
        type: "integer"
        default: 2
      forApi:
        type: "string"

  create: ( name, details, cb ) ->
    # if there isn't a forApi field then `super` will take care of
    # that
    if details.forApi
      @gatekeeper.model( "api" ).find details.forApi, ( err, apiDetails ) =>
        return cb err if err

        if not apiDetails
          return cb new ValidationError "API '#{ name }' doesn't exist."

        ApiKey.__super__.create.apply @, [ name, details, cb ]
    else
      super
