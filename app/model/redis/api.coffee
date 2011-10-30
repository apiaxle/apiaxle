{ ApiUnknown } = require "../../../lib/error"
{ Redis } = require "../redis"

class exports.Api extends Redis
  @instantiateOnStartup = true

  @structure =
    type: "object"
    properties:
      endpoint:
        type: "string"
      apiFormat:
        type: "string"
        enum: [ "json", "xml" ]
        default: "json"
