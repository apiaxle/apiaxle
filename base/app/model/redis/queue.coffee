# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
request = require "request"
async = require "async"
qs = require "querystring"

{ ValidationError } = require "../../../lib/error"
{ Redis } = require "../redis"
{ EventEmitter } = require "events"

class exports.Queue extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "q"

  constructor: ( app ) ->
    super app

    @ee = new EventEmitter()
    @channame_cache = {}

    # get a message, parse the chan (it's come from our redis key
    # manipulation stuff)
    app.redisClient.on "message", ( chan, message ) =>
      parsed_chan = @_getHitName( chan )
      switch parsed_chan
        when "hit" then @ee.emit "hit", chan, message

  _getHitName: ( chan ) ->
    return @channame_cache[chan] if @channame_cache[chan]

    # keep hold of the result for use later, running that re is
    # expensive
    parts = /:([^:]+)$/.exec chan
    @channame_cache[chan] = parts[1]
