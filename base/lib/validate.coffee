_ = require "underscore"

{ ValidationError } = require "./error"

module.exports = ( structure, data, cb ) ->
  validation = structure.validate data

  if validation.errors.length > 0
    errors = []

    for e in validation.errors
      errors.push "#{ e.path.join "." }: (#{ e.attribute }) #{ e.description }"

    return cb new ValidationError errors.join ","
  else
    return cb null, validation.instance
