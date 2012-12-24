#!/usr/bin/env coffee

{ OptionParser } = require "parseopt"

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

  walkTree "./release/release.d", null, ( path, filename, stats ) ->
    # just coffeescript or js and must start with a number
    return unless /^\d+.*?\.(js|coffee)$/.exec filename

    # load the file
    exports = require "./release.d/#{ filename }"
    for name, kls of exports
      object = new kls new_version, [ "api", "base", "proxy" ]

      # allow the plugins to define some args
      object.getArguments parser

      all_executions.push ( cb ) -> object.execute cb

  async.series all_executions, ( err ) ->
    throw err if err

loadPlugins()
