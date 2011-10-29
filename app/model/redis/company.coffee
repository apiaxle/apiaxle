_ = require "underscore"

{ CompanyUnknown } = require "../../../lib/error"

{ Redis } = require "../redis"

class exports.Company extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "cmp"

  new: ( name, details, cb ) ->
    @hmset name, details, cb

  find: ( name, cb ) ->
    @hgetall name, ( err, details ) ->
      return cb err, null if err

      return cb null, null unless _.size( details )

      return cb null, details
