#!/usr/bin/env coffee
# -*- mode: coffee; -*-

util = require "util"
async = require "async"

{ ReplHelper } = require "./lib/repl"
{ Application } = require "apiaxle-base"
{ ApiaxleApi } = require "apiaxle-api"

finish = ( app ) ->
  app.express.close()
  app.redisClient.quit()

axle = new ApiaxleApi
  host: "127.0.0.1"
  port: 28902
  name: "apiaxle"

all = []

all.push ( cb ) -> axle.configure cb
all.push ( cb ) -> axle.loadAndInstansiatePlugins cb
all.push ( cb ) -> axle.redisConnect cb
all.push ( cb ) -> axle.run cb

async.series all, ( err ) ->
  throw err if err

  replHelper = new ReplHelper axle

  # make sure we shutdown connections
  replHelper.initReadline ( ) ->
    finish axle

  replHelper.topLevelInput()
