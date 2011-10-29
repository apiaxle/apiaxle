_ = require "underscore"

{ ApiUnknown } = require "../../../lib/error"

{ Redis } = require "../redis"

class exports.Api extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "cmp"

  new: ( name, details, cb ) ->
    # TODO: http://davidwalsh.name/json-validation
    details.created_at = new Date().getTime()
    @hmset name, details, cb

  find: ( name, cb ) ->
    @hgetall name, ( err, details ) ->
      return cb err, null if err

      return cb null, null unless _.size( details )

      details.endpointTimeout or= 2000
      details.maxRedirects or= 3

      return cb null, details
