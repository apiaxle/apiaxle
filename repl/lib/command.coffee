_ = require "lodash"

{ Module, httpHelpers } = require "apiaxle-base"

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
    return @help cb if not id or id is ""
    return @show id, rest, keypairs, cb if not command?
    return this[ command ] id, rest, keypairs, cb if ( command of this )

    return cb new Error "Invalid syntax. Try 'help'."

  help: ( cb ) ->
    parent_methods = _.methods Command::
    my_methods     = _.methods this

    diff = _.difference my_methods, parent_methods

    return cb null, "Available methods: #{ diff.join ', ' }"

  callApi: ( verb, options, cb ) =>
    default_options =
      headers:
        "content-type": "application/json"

    options = _.extend options, default_options

    log = "Calling (#{ verb }) '#{ options.path }'"
    if options.data
      log += " with '#{ options.data }' as the body."

    @app.logger.info log

    this[ verb ] options, ( err, res ) =>
      return cb err if err
      return @handleApiResults res, cb

  handleApiResults: ( res, cb ) ->
    res.parseJson ( err, json ) ->
      return cb err if err

      # the api itself threw an error
      status = res.statusCode
      if status > 200 and status < 400 and json.results?.error?
        { type, message } = json.results.error
        return cb new Error "#{ type }: #{ message }"

      return cb null, json

  constructor: ( @app, @id ) ->
