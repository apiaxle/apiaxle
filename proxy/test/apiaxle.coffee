# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
# always run as test
process.env.NODE_ENV = "test"

async = require "async"

{ ApiaxleProxy } = require "../apiaxle-proxy"
{ AppTest } = require "apiaxle-base"

{ GetCatchall, DeleteCatchall } = require "../app/controller/catchall_controller"

class exports.ApiaxleTest extends AppTest
  @appClass = ApiaxleProxy

  configureApp: ( cb ) ->
    all = []

    all.push ( cb ) => @app.configure cb
    all.push ( cb ) => @app.loadAndInstansiatePlugins cb
    all.push ( cb ) => @app.redisConnect cb

    async.series all, ( err ) ->
      console.log( err ) if err
      cb()

  stubCatchall: ( cb ) ->
    @getStub GetCatchall::, "_httpRequest", cb

  stubCatchallDelete: ( cb ) ->
    @getStub DeleteCatchall::, "_httpRequest", cb

  stubCatchallSimpleDelete: ( status, body, headers={} ) ->
    @stubCatchallDelete ( options, api, key, keyrings, cb ) =>
      @fakeIncomingMessage status, body, headers, ( err, res ) ->
        body = options if not body
        return cb err, res, body

  stubCatchallSimpleGet: ( status, body, headers={} ) ->
    @stubCatchall ( options, api, key, keyrings, cb ) =>
      @fakeIncomingMessage status, body, headers, ( err, res ) ->
        body = options if not body
        return cb err, res, body
