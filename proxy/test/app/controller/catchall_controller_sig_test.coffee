async = require "async"

{ ApiaxleTest } = require "../../apiaxle"

class exports.CatchallTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "test signatures and expiary times": ( done ) ->
    apiOptions =
      apiFormat: "json"
      globalCache: 30

    keyOptions =
      sharedSecret: "bob-the-builder"

    @newApiAndKey "facebook", apiOptions, "1234", keyOptions, ( err ) =>
      @isNull err

      stub = @stubCatchall 200, {},
        "Content-Type": "application/json"

      @GET { path: "/?api_key=1234", host: "facebook.api.localhost" }, ( err, response ) =>
        @isNull err

        response.parseJson ( json ) =>
          @ok err = json.error
          @equal err.type, "ApiKeyError"
          @equal err.message, "A signature is required for this API."

        @GET { path: "/?api_key=1234&api_sig=5678", host: "facebook.api.localhost" }, ( err, response ) =>
          @isNull err

          response.parseJson ( json ) =>
            @ok err = json.error
            @equal err.type, "ApiKeyError"
            @match err.message, /Invalid signature/

            done 9
