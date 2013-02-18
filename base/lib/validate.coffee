_ = require "underscore"
amanda = require "amanda"

{ ValidationError } = require "./error"

module.exports = ( structure, data, cb ) ->
  jsonSchemaValidator = amanda "json"

  jsonSchemaValidator.validate data, structure, cb
