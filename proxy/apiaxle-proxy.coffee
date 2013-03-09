#!/usr/bin/env coffee

express = require "express"
fs      = require "fs"
redis   = require "redis"

{ Application } = require "apiaxle-base"

class exports.ApiaxleProxy extends Application
  @controllersPath = "#{ __dirname }/app/controller"

if not module.parent
  # taking a port from the commandline makes it much easier to cluster
  # the app
  port = ( process.argv[2] or 3000 )
  host = "127.0.0.1"

  proxy = new exports.ApiaxleProxy host, port

  proxy.redisConnect ( ) ->
    proxy.run ( ) ->
      proxy.configureModels()
      proxy.configureControllers()
      proxy.configureMiddleware()

      console.log "Express server listening on port #{port}"
