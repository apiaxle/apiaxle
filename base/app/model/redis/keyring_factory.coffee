async = require "async"

{ Redis, Model } = require "../redis"

validationEnv = require( "schema" )( "apiEnv" )

class Keyring extends Model

class exports.KeyringFactory extends Redis
  @instantiateOnStartup = true
  @returns = Keyring
  @structure = validationEnv.Schema.create
    type: "object"
    additionalProperties: false
