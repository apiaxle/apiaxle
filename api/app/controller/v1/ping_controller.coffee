# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
_ = require "lodash"

mypackage = require "../../../package.json"
basepackage = require( "apiaxle-base" ).package

{ ApiaxleController, ListController } = require "../controller"
{ AlreadyExists } = require "../../../lib/error"

class exports.Ping extends ApiaxleController
  @verb = "get"

  desc: -> "Ping controller."

  docs: ->
    {}=
      verb: "GET"
      title: "Ping the API for a super fast response."
      response: "Just a 'pong'."

  path: -> "/v1/ping"

  execute: ( req, res, next ) ->
    res.type "text"
    res.send "pong"
