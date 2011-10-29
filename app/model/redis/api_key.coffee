_ = require "underscore"
{ Redis } = require "../redis"

class exports.ApiKey extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "key"

  new: ( name, details, cb ) ->
    # TODO: http://davidwalsh.name/json-validation
    details.created_at = new Date().getTime()
    @hmset name, details, cb

  find: ( key, cb ) ->
    @hgetall key, ( err, details ) ->
      return cb err, null if err

      return cb null, null unless _.size( details )

      return cb null, details
