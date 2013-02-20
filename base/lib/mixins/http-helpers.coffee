_ = require "underscore"
libxml = require "libxmljs"
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

exports.httpHelpers =
  httpRequest: ( options, callback ) ->
    defaults =
      host: "127.0.0.1"
      port: @constructor.port

    # fill in the defaults (though, why port would change, I don't
    # know)
    options = _.extend defaults, options

    @app.logger.debug "Making a #{ options.method} to #{ options.path }"
    req = http.request options, ( res ) ->
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

  POST: ( options, callback ) ->
    options.method = "POST"

    @httpRequest options, callback

  GET: ( options, callback ) ->
    options.method = "GET"

    # never GET data
    delete options.data

    @httpRequest options, callback

  PUT: ( options, callback ) ->
    options.method = "PUT"

    @httpRequest options, callback

  DELETE: ( options, callback ) ->
    options.method = "DELETE"

    @httpRequest options, callback
