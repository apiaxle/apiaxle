#!/usr/bin/env coffee

fs = require "fs"
redis = require "redis"
async = require "async"

cluster = require "cluster"
cpus = require("os").cpus()

{ AxleApp } = require "apiaxle-base"

class exports.ApiaxleProxy extends AxleApp
  @plugins =
    controllers: "#{ __dirname }/app/controller/*_controller.{js,coffee}"

if not module.parent
  # taking a port from the commandline makes it much easier to cluster
  # the app
  port = ( process.argv[2] or 3000 )
  host = "127.0.0.1"

  if cluster.isMaster
    # fork for each CPU
    for i in cpus
      cluster.fork()

    cluster.on "exit", ( worker, code, signal ) ->
      console.log( "Worker #{ worker.process.pid } died." )

  else
    api = new exports.ApiaxleProxy
      name: "apiaxle"
      port: port
      host: host

    all = []

    all.push ( cb ) -> api.configure cb
    all.push ( cb ) -> api.loadAndInstansiatePlugins cb
    all.push ( cb ) -> api.redisConnect cb
    all.push ( cb ) -> api.initErrorHandler cb
    all.push ( cb ) -> api.run cb

    async.series all, ( err ) ->
      throw err if err
