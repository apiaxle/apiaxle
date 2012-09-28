_ = require "underscore"

{ Redis } = require "../redis"
{ ValidationError } = require "../../../lib/error"

validationEnv = require( "schema" )( "apiKeyEnv" )

class exports.ApiKey extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "keys"

  @structure = validationEnv.Schema.create
    type: "object"
    additionalProperties: false

  add_key: (api, key) ->
    @lpush "#{ api }:keys", key

  get_keys: (api, start, stop, cb) ->
    @lrange "#{ api }:keys", start, stop, cb
