{ GatekeeperTest } = require "../../gatekeeper"

class exports.CatchallTest extends GatekeeperTest
  @start_webserver = true

  "test simple request": ( done ) ->
    @ok 1

    @GET { path: "/" }, ( err, response ) =>
      console.log( response.statusCode )
      console.log( response.data )

      done 1
