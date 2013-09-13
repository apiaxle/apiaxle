# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
async = require "async"

# always run as test
process.env.NODE_ENV = "test"

{ ApiaxleApi } = require "../apiaxle-api"
{ AppTest } = require "apiaxle-base"

class exports.ApiaxleTest extends AppTest
  @appClass = ApiaxleApi

  configureApp: ( cb ) ->
    all = []

    all.push ( cb ) => @app.configure cb
    all.push ( cb ) => @app.redisConnect "redisClient", cb
    all.push ( cb ) => @app.loadAndInstansiatePlugins cb
    all.push ( cb ) => @app.initFourOhFour cb
    all.push ( cb ) => @app.initErrorHandler cb

    async.series all, ( err ) ->
      console.log( err ) if err

      cb()
