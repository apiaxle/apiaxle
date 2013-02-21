_ = require "underscore"

{ httpHelpers } = require "../lib/mixins/http-helpers"
{ Module } = require "../lib/module"

class AppResponse
  constructor: ( @actual_res, @data ) ->
    @statusCode  = @actual_res.statusCode
    @headers     = @actual_res.headers
    @contentType = @headers[ "content-type" ]

  withJquery: ( callback ) ->
    jsdom.env @data, ( errs, win ) =>
      throw new Error errs if errs

      jq = require( "jquery" ).create win

      callback jq

  parseXml: ( callback ) ->
    try
      output = libxml.parseXmlString @data
    catch err
      return callback err, null

    return callback null, output

  parseJson: ( callback ) ->
    try
      output = JSON.parse @data, "utf8"
    catch err
      return callback err, null

    return callback null, output

class exports.Command extends Module
  @port = 28902

  # mixin the httpHeler functions (POST, GET, etc...)
  @include httpHelpers

  exec: ( [ id, command, rest... ], keypairs, cb ) ->
    if not id or id is ""
      return cb new Error "api needs an id of an api as the second argument."

    if not command?
      return @show id, rest, keypairs, cb

    if ( command of @ )
      return @[ command ] id, rest, keypairs, cb

  callApi: ( verb, options, cb ) =>
    default_options =
      headers:
        "content-type": "application/json"

    options = _.extend options, default_options

    @[ verb ] options, ( err, res ) =>
      return cb err if err
      return @handleApiResults res, cb

  handleApiResults: ( res, cb ) ->
    res.parseJson ( err, json ) ->
      return cb err if err

      # the api itself threw an error
      if json.results?.error?
        return cb new Error json.results.error.message

      return cb null, json

  constructor: ( @app, @id ) ->
