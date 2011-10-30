#!/usr/bin/env coffee

sys = require "sys"

{ OptionParser } = require "parseopt"
{ Gatekeeper } = require "../gatekeeper"

parser = new OptionParser
  minargs: 1
  strings:
    arguments: "KEY"

parser.add "--qpd",
  type: "integer"
  help: "Queries per day."
  default: 86400

parser.add "--qps",
  type: "integer"
  help: "Queries per second."
  default: 1

parser.add "--for-api",
  type: "string"
  help: "The api this key works with."
  required: true

try
  options = parser.parse( )
catch e
  parser.usage()
  process.exit 1

[ name ] = options.arguments

gk = new Gatekeeper()
gk.script ( finish ) ->
  model = gk.model "apiKey"

  model.create name, options.options, ( err ) ->
    throw err if err

    model.find name, ( err, newKey ) ->
      throw err if err

      console.log newKey

      finish()
