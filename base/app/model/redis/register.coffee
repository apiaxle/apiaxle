request = require "request"
async = require "async"
qs = require "querystring"

{ QpsExceededError, QpdExceededError } = require "../../../lib/error"
{ Redis } = require "../redis"

class exports.Register extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "reg"

  isRegistered: ( cb ) ->
    @get "registered", ( err, value ) ->
      return cb err if err
      return cb null, not not value

  register: ( email, name, cb ) ->
    params =
      email: email
      name: name

    options =
      strictSSL: false
      url: "https://test.apiaxle.com?#{ qs.stringify params }"
      timeout: 5000

    request.get options, ( err ) =>
      return cb err if err
      @set "registered", "#{ email },#{ name }", cb
