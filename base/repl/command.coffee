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

  constructor: ( @app, @id ) ->

class exports.ModelCommand extends exports.Command
  model: ( ) ->
    return @_model if @_model
    return ( @_model = @app.model( @constructor.modelName ) )

  modelProps: ( ) ->
    ( @model().constructor.structure.properties or [] )

  _getIdAndObject: ( commands, cb ) ->
    @_getId commands, ( err, id ) =>
      return cb err if err

      @model().find id, ( err, dbObj ) ->
        return cb err if err
        return cb null, id, dbObj

  _getId: ( id, cb ) ->
    if not id? or typeof( id ) isnt "string"
      return cb new Error "Expecting an ID (string) as the first argument."

    return cb null, id
