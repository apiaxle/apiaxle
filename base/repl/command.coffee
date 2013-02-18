_ = require "underscore"
http = require "http"

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

class exports.Command
  constructor: ( @app, @id ) ->

  # returns a AppResponse object
  POST: ( options, callback ) ->
    options.method = "POST"

    @httpRequest options, callback

  # returns a AppResponse object
  GET: ( options, callback ) ->
    options.method = "GET"

    # never GET data
    delete options.data

    @httpRequest options, callback

  # returns a AppResponse object
  PUT: ( options, callback ) ->
    options.method = "PUT"

    @httpRequest options, callback

  # returns a AppResponse object
  DELETE: ( options, callback ) ->
    options.method = "DELETE"

    @httpRequest options, callback

  # returns a AppResponse object
  httpRequest: ( options, callback ) ->
    defaults =
      host: "127.0.0.1"
      port: 28902

    # fill in the defaults (though, why port would change, I don't
    # know)
    for key, val of defaults
      options[ key ] = val unless options[ key ]

    @app.logger.debug "Making a #{ options.method} to #{ options.path }"
    req = http.request options, ( res ) =>
      data = ""
      res.setEncoding "utf8"

      res.on "data", ( chunk ) -> data += chunk
      res.on "error", ( err )  -> callback err, null
      res.on "end", ( )        -> callback null, new AppResponse( res, data )

    req.on "error", ( err ) -> callback err, null

    # write the body if we're meant to
    if options.data and options.method not in [ "HEAD", "GET" ]
      req.write options.data

    req.end()

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
        return cb null, dbObj

  _getId: ( commands, cb ) ->
    id = commands.shift()

    if not id? or typeof( id ) isnt "string"
      return cb new Error "Expecting an ID (string) as the first argument."

    return cb null, id
