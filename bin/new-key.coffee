#!/usr/bin/env coffee

sys = require "sys"

{ OptionParser } = require "parseopt"
{ Gatekeeper } = require "../gatekeeper"

parser = new OptionParser
  minargs: 1
  strings:
    arguments: "KEY"

parser.add "--for-company",
  type: "string"
  help: "The company this key works with."
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

  model.new name, options.options, ( err ) ->
    throw err if err

    model.find name, ( err, newKey ) ->
      throw err if err

      console.log newKey

      finish()
