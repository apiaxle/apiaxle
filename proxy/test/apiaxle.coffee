# always run as test
process.env.NODE_ENV = "test"

{ ApiaxleProxy } = require "../apiaxle-proxy"
{ AppTest } = require "apiaxle-base"

{ GetCatchall, DeleteCatchall } = require "../app/controller/catchall_controller"

class exports.ApiaxleTest extends AppTest
  @appClass = ApiaxleProxy

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
