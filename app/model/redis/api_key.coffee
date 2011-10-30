_ = require "underscore"
{ Redis } = require "../redis"

class exports.ApiKey extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "key"

  @structure =
    type: "object"
    properties:
      qpd:
        type: "integer"
        default: 1:  172800
      qps:
        type: "integer"
        default: 2
      forApi:
        type: "string"
