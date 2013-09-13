#!/usr/bin/env coffee

# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.

async = require "async"
stdin = require "stdin"

{ ReplHelper } = require "./lib/repl"
{ ApiaxleApi } = require "apiaxle-api"

finish = ( app ) ->
  app.redisClient.quit()
  app.close()

axle = new ApiaxleApi
  host: "127.0.0.1"
  port: 28902
  name: "apiaxle"

all = []

all.push ( cb ) -> axle.configure cb
all.push ( cb ) -> axle.redisConnect "redisClient", cb
all.push ( cb ) -> axle.loadAndInstansiatePlugins cb
all.push ( cb ) -> axle.initFourOhFour cb
all.push ( cb ) -> axle.initErrorHandler cb
all.push ( cb ) -> axle.run cb    # run the server

async.series all, ( err, res ) ->
  throw err if err

  replHelper = new ReplHelper axle
  if process.stdin.isTTY
    replHelper.initReadline ( ) -> finish axle
    replHelper.topLevelInput()
  else
    stdin ( str ) ->
      line_processors = []
      for line in str.split /\r?\n/
        do( line ) ->
          line_processors.push ( cb ) ->
            replHelper.processLine line, ( err, info ) ->
              replHelper.handleReturn err, info
              cb()

      async.series line_processors, ( err ) ->
        finish axle
