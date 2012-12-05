async = require "async"

{ Redis } = require "../redis"

validationEnv = require( "schema" )( "apiEnv" )

class Keyring extends Redis

class exports.KeyringFactory extends Redis
  @instantiateOnStartup = true
  @returns = Keyring
  @structure = validationEnv.Schema.create
    type: "object"
    additionalProperties: false
