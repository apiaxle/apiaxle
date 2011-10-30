_ = require "underscore"

{ ValidationError } = require "../lib/error"
{ validate } = require "../vendor/json-schema"

module.exports = ( structure, data, cb ) ->
  validation = validate data, structure

  if validation.errors.length > 0
    errors = { }
    for e in validation.errors
      errors[ ( e.property or "root" ) ] = e.message

    cb new ValidationError errors
  else
    cb null, validation
