# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
async = require "async"

{ Redis, KeyContainerModel } = require "../redis"
{ ValidationError } = require "../../../lib/error"

class Keyring extends KeyContainerModel
  @reverseLinkFunction = "linkToKeyring"
  @reverseUnlinkFunction = "unlinkFromKeyring"

class exports.KeyringFactory extends Redis
  @instantiateOnStartup = true
  @returns = Keyring
  @structure =
    type: "object"
    additionalProperties: false
    properties:
      createdAt:
        type: "integer"
        optional: true
      updatedAt:
        type: "integer"
        optional: true
