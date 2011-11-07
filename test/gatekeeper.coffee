# always run as test
process.env.NODE_ENV = "test"

{ GatekeeperProxy } = require "../gatekeeper_proxy"
{ AppTest } = require "gatekeeper.base"

{ GetCatchall } = require "../app/controller/catchall_controller"

class exports.GatekeeperTest extends AppTest
  @appClass = GatekeeperProxy

  stubCatchall: ( status, body, headers={} ) ->
    # stub out the http request in the controller that we do
    @getStub GetCatchall::, "_httpRequest", ( options, cb ) =>
      @fakeIncomingMessage status, body, headers, ( err, res ) =>
        return cb err, res, body
