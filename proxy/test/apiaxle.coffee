# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
# always run as test
process.env.NODE_ENV = "test"

async = require "async"

{ ApiaxleProxy } = require "../apiaxle-proxy"
{ AppTest } = require "apiaxle-base"

class exports.ApiaxleTest extends AppTest
  @appClass = ApiaxleProxy

  configureApp: ( cb ) ->
    all = []

    all.push ( cb ) => @app.configure cb
    all.push ( cb ) => @app.redisConnect cb
    all.push ( cb ) => @app.loadAndInstansiatePlugins cb

    async.series all, ( err ) ->
      console.log( err ) if err
      cb()
