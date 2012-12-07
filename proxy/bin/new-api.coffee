#!/usr/bin/env coffee

{ OptionParser } = require "parseopt"
{ ApiaxleProxy } = require "../apiaxle_proxy"

parser = new OptionParser
  minargs: 1
  strings:
    arguments: "COMPANY NAME"

parser.add "--end-point-timeout",
  type: "integer"
  help: "The request will timeout after n seconds."
  default: 5

parser.add "--end-point-max-redirects",
  type: "integer"
  help: "The maximum number of re-directs allowed for endpoint"
  default: 2

parser.add "--end-point",
  type: "string"
  help: "The endpoint (url) this api's api will listen at."
  required: true

parser.add "--api-format",
  type: "enum"
  values: [ "json", "xml" ]
  default: "json"
  help: "Format of the api."

parser.add "--global-cache",
  type: "int"
  default: 0
  help: "Seconds to cache each hit."

try
  options = parser.parse( )
catch e
  parser.usage()
  process.exit 1

[ name ] = options.arguments

gk = new ApiaxleProxy()
gk.script ( finish ) ->
  model = gk.model "apiFactory"

  model.create name, options.options, ( err ) ->
    throw err if err

    model.find name, ( err, newApi ) ->
      throw err if err

      console.log newApi.data

      finish()
