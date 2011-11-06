{ GatekeeperProxy } = require "../gatekeeper_proxy"
{ AppTest } = require "gatekeeper.base"

class exports.GatekeeperTest extends AppTest
  @appClass = GatekeeperProxy
