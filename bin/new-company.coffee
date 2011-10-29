#!/usr/bin/env coffee

sys = require "sys"

{ OptionParser } = require "parseopt"
{ Gatekeeper } = require "../gatekeeper"

parser = new OptionParser
  minargs: 1
  strings:
    arguments: "COMPANY NAME"

parser.add "--endpoint",
  type: "string"
  help: "The endpoint (url) this company's api will listen at."
  required: true

parser.add "--api-format",
  type: "enum"
  values: [ "json", "xml" ]
  default: "json"
  help: "Format of the api."

try
  options = parser.parse( )
catch e
  parser.usage()
  process.exit 1

[ name ] = options.arguments

gk = new Gatekeeper()
gk.script ( finish ) ->
  model = gk.model "company"

  model.new name, options.options, ( err ) ->
    throw err if err

    model.find name, ( err, newCompany ) ->
      throw err if err

      console.log newCompany

      finish()
