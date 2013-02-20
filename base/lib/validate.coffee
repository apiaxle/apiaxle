_ = require "underscore"

{ ValidationError } = require "./error"

amanda = require "amanda"
jsonSchemaValidator = amanda "json"

validRegexpAttribute = ( prop, data, value, attrbs, cb ) ->
  return cb() unless value

  try
    new RegExp data
  catch err
    @addError err

  return cb()

jsonSchemaValidator.addAttribute "is_valid_regexp", validRegexpAttribute

module.exports = ( structure, data, cb ) ->
  jsonSchemaValidator.validate data, structure, ( err ) ->
    if err
      message = ""

      for details in err
        message += "#{ details.property }: #{ details.message }"

      return cb new ValidationError message

    # set defaults if need be
    for key, details of structure.properties
      if not data[ key ]? and details.default?
        data[ key ] = details.default

    return cb null, data
