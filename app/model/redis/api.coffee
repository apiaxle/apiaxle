_ = require "underscore"
validate = require "../../../lib/validate"

{ ApiUnknown } = require "../../../lib/error"
{ Redis } = require "../redis"

class exports.Api extends Redis
  @instantiateOnStartup = true

  @endpointTimeout = 2000
  @maxRedirects = 3

  @newValidation =
    type: "object"
    properties:
      endpoint:
        type: "string"
      apiFormat:
        type: "string"
        enum: [ "json", "xml" ]

  new: ( name, details, cb ) ->
    validate @constructor.newValidation, details, ( err ) =>
      return cb err if err

      details.createdAt = new Date().getTime()
      @hmset name, details, cb

  find: ( name, cb ) ->
    @hgetall name, ( err, details ) ->
      return cb err, null if err

      return cb null, null unless _.size( details )

      details.endpointTimeout or= @constructor.endpointTimeout
      details.maxRedirects or= @constructor.maxRedirects

      return cb null, details
