async = require "async"

{ QpsExceededError, QpdExceededError } = require "../../../lib/error"
{ Redis } = require "../redis"

class exports.Register extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "reg"

  isRegistered: ( cb ) ->
    @get "registered", ( err, value ) ->
      return cb err if err
      return cb null, value is "true"

  register: ( cb ) -> @set "registered", "true", cb
