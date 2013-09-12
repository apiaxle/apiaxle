# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
request = require "request"
async = require "async"
qs = require "querystring"

{ ValidationError } = require "../../../lib/error"
{ Redis } = require "../redis"

class exports.Queue extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "q"

  constructor: ( app ) ->
    @on = app.redisClient.on
    super app