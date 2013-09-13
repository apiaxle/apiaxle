#!/usr/bin/env coffee

# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.

_ = require "lodash"
urllib = require "url"
async = require "async"
httpProxy = require "http-proxy"

cluster = require "cluster"

{ AxleApp } = require "apiaxle-base"

class exports.ApiaxleQueueProcessor extends AxleApp
  @plugins = {}

  processHit: ( options ) ->
    { api_name,
      key_name,
      keyring_names,
      timing,
      parsed_url } = options

  error: ( err ) ->
    @logger.warn "#{ err.name } - #{ err.message }"

  run: ->
    queue = @model( "queue" )

    queue.ee.on "hit", ( chan, message ) =>
      @processHit JSON.parse( message )

    queue.subscribe "hit"

if not module.parent
  optimism = require( "optimist" ).options
    f:
      alias: "fork-count"
      default: 1
      describe: "How many internal processes to fork"

  optimism.boolean "help"
  optimism.describe "help", "Show this help screen"

  if optimism.argv.help or optimism.argv._.length > 0
    optimism.showHelp()
    process.exit 0

  if cluster.isMaster
    # fork for each CPU or the specified amount
    cluster.fork() for i in [ 1..optimism.argv["fork-count"] ]

    cluster.on "exit", ( worker, code, signal ) ->
      console.log( "Worker #{ worker.process.pid } died." )
  else
    api = new exports.ApiaxleQueueProcessor()

    all = []

    all.push ( cb ) -> api.configure cb
    all.push ( cb ) -> api.redisConnect "redisClient", cb
    all.push ( cb ) -> api.loadAndInstansiatePlugins cb
    all.push ( cb ) -> api.run cb

    async.series all, ( err ) ->
      throw err if err
