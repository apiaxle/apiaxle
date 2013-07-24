# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
#!/usr/bin/env coffee

# extends Date
async = require "async"
express = require "express"

cluster = require "cluster"
cpus = require("os").cpus()

{ AxleApp } = require "apiaxle-base"

class exports.ApiaxleApi extends AxleApp
  @plugins =
    controllers: "#{ __dirname }/app/controller/**/*_controller.{js,coffee}"

  configure: ( cb ) ->
    @use express.methodOverride()
    @use express.bodyParser()

    super cb

if not module.parent
  optimism = require( "optimist" ).options
    p:
      alias: "port"
      default: 3000
      describe: "Port to bind the proxy to."
    h:
      alias: "host"
      default: "127.0.0.1"
      describe: "Host to bind the proxy to."
    f:
      alias: "fork-count"
      default: cpus.length
      describe: "How many internal processes to fork"

  optimism.boolean "help"
  optimism.describe "help", "Show this help screen"

  if optimism.argv.help or optimism.argv._.length > 0
    optimism.showHelp()
    process.exit 0

  # taking a port from the commandline makes it much easier to cluster
  # the app
  { port, host } = optimism.argv

  if cluster.isMaster
    # fork for each CPU or the specified amount
    cluster.fork() for i in [ 1..optimism.argv["fork-count"] ]

    cluster.on "exit", ( worker, code, signal ) ->
      console.log( "Worker #{ worker.process.pid } died." )
  else
    api = new exports.ApiaxleApi
      name: "apiaxle"
      port: port
      host: host

    all = []

    all.push ( cb ) -> api.configure cb
    all.push ( cb ) -> api.loadAndInstansiatePlugins cb
    all.push ( cb ) -> api.initFourOhFour cb
    all.push ( cb ) -> api.initErrorHandler cb
    all.push ( cb ) -> api.redisConnect cb
    all.push ( cb ) -> api.run cb

    async.series all, ( err ) ->
      throw err if err
