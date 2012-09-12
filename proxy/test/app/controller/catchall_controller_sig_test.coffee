crypto = require "crypto"
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

      tests = []

      tests.push ( cb ) =>
        @GET { path: "/?api_key=1234", host: "facebook.api.localhost" }, ( err, response ) =>
          @isNull err

          response.parseJson ( json ) =>
            @ok err = json.error
            @equal err.type, "ApiKeyError"
            @equal err.message, "A signature is required for this API."

            cb()

      tests.push ( cb ) =>
        @GET { path: "/?api_key=1234&api_sig=5678", host: "facebook.api.localhost" }, ( err, response ) =>
          @isNull err

          response.parseJson ( json ) =>
            @ok err = json.error
            @equal err.type, "ApiKeyError"
            @match err.message, /Invalid signature/

            cb()

      tests.push ( cb ) =>
        date = Math.floor( Date.now() / 1000 / 3 ).toString()

        md5 = crypto.createHash "md5"
        md5.update "bob-the-builder"
        md5.update date
        md5.update "1234"

        validSig = md5.digest "hex"

        httpOptions =
          path: "/?api_key=1234&api_sig=#{validSig}"
          host: "facebook.api.localhost"

        @GET httpOptions, ( err, response ) =>
          @isNull err

          response.parseJson ( json ) =>
            @isUndefined json["error"]
            @ok json

            cb()

      async.parallel tests, ( err ) =>
        @isNull err

        done 13
