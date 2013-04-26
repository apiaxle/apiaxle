_ = require "lodash"

mypackage = require "../../../package.json"
basepackage = require( "apiaxle-base" ).package

{ ApiaxleController, ListController } = require "../controller"
{ AlreadyExists } = require "../../../lib/error"

class exports.Ping extends ApiaxleController
  @verb = "get"

  desc: -> "Ping controller."

  docs: ->
    """
    ### Returns

    * Just a pong.
    """

  path: -> "/v1/ping"

  execute: ( req, res, next ) ->
    res.type "text"
    res.send "pong"
