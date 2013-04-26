#!/usr/bin/env coffee

# extends Date
_ = require "lodash"
async = require "async"
express = require "express"
fs = require "fs"

{ AxleApp } = require "apiaxle-base"
{ NotFoundError } = require "./lib/error"

class exports.ApiaxleApi extends AxleApp
  @plugins =
    controllers: "#{ __dirname }/app/controller/**/*_controller.coffee"

  configure: ( cb ) ->
    @use express.methodOverride()
    @use express.bodyParser()

    super cb

if not module.parent
  # taking a port from the commandline makes it much easier to cluster
  # the app
  port = ( process.argv[2] or 3000 )
  host = "127.0.0.1"

  api = new exports.ApiaxleApi
    name: "apiaxle"
    port: port
    host: host

  all = []

  all.push ( cb ) -> api.configure cb
  all.push ( cb ) -> api.loadAndInstansiatePlugins cb
  all.push ( cb ) -> api.redisConnect cb
  all.push ( cb ) -> api.run cb

  async.series all, ( err ) ->
    throw err if err
