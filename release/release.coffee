#!/usr/bin/env axle-coffee

{ OptionParser } = require "parseopt"
{ StdoutLogger } = require "../base/lib/stderrlogger"

async    = require "async"
walkTree = require "../base/lib/walktree"

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
  logger = new StdoutLogger()

  walkTree "./release/release.d", null, ( path, filename, stats ) ->
    # just coffeescript or js and must start with a number
    return unless /^\d+.*?\.(js|coffee)$/.exec filename

    # load the file
    exports = require "./release.d/#{ filename }"
    for name, kls of exports
      logger.info "Found '#{ name }'. Loading."

      object = new kls logger, new_version, [ "api", "base", "proxy" ]

      # allow the plugins to define some args
      object.getArguments parser

      all_executions.unshift ( cb ) -> object.execute cb

  async.series all_executions, ( err, res ) ->
    # logging taken care of output
    process.exit 1 if err

loadPlugins()
