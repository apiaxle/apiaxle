{ GatekeeperTest } = require "../../gatekeeper"

class exports.CatchallTest extends GatekeeperTest
  @start_webserver = true

  "test POST with no domain": ( done ) ->
    @POST { path: "/", data: "something" }, ( err, response ) =>
      response.parseJson ( json ) =>
        @ok json.error
        @equal json.error.type, "ApiUnknown"

        done 2

  "test GET with no domain": ( done ) ->
    @GET { path: "/" }, ( err, response ) =>
      response.parseJson ( json ) =>
        @ok json.error
        @equal json.error.type, "ApiUnknown"

        done 2

  "test PUT with no domain": ( done ) ->
    @PUT { path: "/", data: "something" }, ( err, response ) =>
      response.parseJson ( json ) =>
        @ok json.error
        @equal json.error.type, "ApiUnknown"

        done 2

  "test DELETE with no domain": ( done ) ->
    @DELETE { path: "/", data: "something" }, ( err, response ) =>
      response.parseJson ( json ) =>
        @ok json.error
        @equal json.error.type, "ApiUnknown"

        done 2
