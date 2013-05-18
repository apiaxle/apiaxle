_ = require "lodash"
libxml = require "libxmljs"
http = require "http"

class AppResponse
  constructor: ( @actual_res, @data ) ->
    @statusCode  = @actual_res.statusCode
    @headers     = @actual_res.headers
    @contentType = @headers[ "content-type" ]

  withJquery: ( cb ) ->
    jsdom.env @data, ( errs, win ) =>
      throw new Error errs if errs

      jq = require( "jquery" ).create win

      cb jq

  parseXml: ( cb ) ->
    try
      output = libxml.parseXmlString @data
    catch err
      return cb err, null

    return cb null, output

  parseJsonSuccess: ( cb ) ->
    @parseJson ( err, json ) ->
      return cb err if err
      return cb new Error json.results.error.message if json.results?.error?
      return cb null, json.meta, json.results

  parseJsonError: ( cb ) ->
    @parseJson ( err, json ) ->
      return cb err if err
      return cb new Error "No Axle style error output found." unless json.results.error?
      return cb null, json.results.error

  parseJson: ( cb ) ->
    try
      output = JSON.parse @data, "utf8"
    catch err
      return cb err, null

    return cb null, output

exports.httpHelpers =
  httpRequest: ( options, cb ) ->
    defaults =
      host: "127.0.0.1"
      port: @constructor.port

    # fill in the defaults (though, why port would change, I don't
    # know)
    options = _.extend defaults, options

    req = http.request options, ( res ) ->
      data = ""
      res.setEncoding "utf8"

      res.on "data", ( chunk ) -> data += chunk
      res.on "error", ( err )  -> cb err, null
      res.on "end", ( )        -> cb null, new AppResponse( res, data )

    req.on "error", ( err ) -> cb err, null

    # write the body if we're meant to
    if options.data and options.method not in [ "HEAD", "GET" ]
      req.write options.data

    req.end()

  POST: ( options, cb ) ->
    options.method = "POST"

    @httpRequest options, cb

  GET: ( options, cb ) ->
    options.method = "GET"

    # never GET data
    delete options.data

    @httpRequest options, cb

  PUT: ( options, cb ) ->
    options.method = "PUT"

    @httpRequest options, cb

  DELETE: ( options, cb ) ->
    options.method = "DELETE"

    @httpRequest options, cb
