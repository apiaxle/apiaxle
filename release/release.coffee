# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
#!/usr/bin/env coffee

{ OptionParser } = require "parseopt"

async = require "async"
log4js = require "log4js"
glob = require "glob"

# fetch the arguments (including the ones from the plugins)
parser = new OptionParser
  minargs: 1
  strings:
    arguments: "NEW VERSION"

try
  # get the version we're going to bump to
  [ new_version ] = parser.parse().arguments
catch e
  parser.usage()
  process.exit 1

# run over the plugins, loading all of the arguments and functions to
# be run
loadPlugins = ( ) ->
  all_executions = []

  # universal logging
  logger = log4js.getLogger()
  logger.setLevel "DEBUG"

  glob "#{ __dirname }/release.d/*.coffee", {}, ( err, files ) ->
    console.log( err ) if err

    for filename in files
      # load the file
      exports = require filename
      for name, kls of exports
        logger.info "Found '#{ name }'. Loading."

        object = new kls logger, new_version, [ "api", "base", "proxy", "repl" ]

        # allow the plugins to define some args
        object.getArguments parser

        all_executions.unshift ( cb ) -> object.execute cb

    async.series all_executions, ( err, res ) ->
      # logging taken care of output
      process.exit 1 if err

loadPlugins()
