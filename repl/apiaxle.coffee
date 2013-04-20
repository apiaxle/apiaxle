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

axle = new ApiaxleApi "127.0.0.1", 28902
axle.redisConnect ( ) ->
  axle.run ( ) ->
    axle.configureControllers()
    axle.configureModels()
    axle.configureMiddleware()

    replHelper = new ReplHelper axle

    # make sure we shutdown connections
    replHelper.initReadline ( ) ->
      finish axle

    replHelper.topLevelInput()
