# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
_ = require "lodash"

mypackage = require "../../../package.json"
basepackage = require( "apiaxle-base" ).package

{ ApiaxleController, ListController } = require "../controller"
{ AlreadyExists } = require "../../../lib/error"

class exports.ViewInfo extends ApiaxleController
  @verb = "get"

  docs: ->
    {}=
      verb: "GET"
      title: "Information about this project."
      response: "Package file output."

  path: -> "/v1/info"

  execute: ( req, res, next ) ->
    return @json res,
      base: basepackage
      api: mypackage
