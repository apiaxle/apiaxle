crypto = require "crypto"
async = require "async"

{ ApiaxleTest } = require "../../apiaxle"

class exports.CatchallTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  @fixture_api_key = "1234"
  @fixture_api_secret = "bob-the-builder"

  "setup api": ( done ) ->
    apiOptions =
      apiFormat: "json"
      globalCache: 30

    keyOptions =
      sharedSecret: @constructor.fixture_api_secret

    @newApiAndKey "facebook", apiOptions, @constructor.fixture_api_key, keyOptions, done

  generateSig: ( epoch ) ->
    date = Math.floor( epoch ).toString()

    md5 = crypto.createHash "md5"
    md5.update @constructor.fixture_api_secret
    md5.update Math.floor( epoch ).toString()
    md5.update @constructor.fixture_api_key

    return md5.digest "hex"

  "test #validateToken": ( done ) ->
    controller = @application.controllers.GetCatchall

    # pause time and get the current epoch
    clock = @getClock()
    now = Math.floor( Date.now() / 1000 )

    all = [ ]

    # all of these should be fine given the three second window
    for validSeconds in [ 0, -1, -2, -3, 1, 2, 3 ]
      do( validSeconds ) =>
        all.push ( cb ) =>
          keyTime = now + validSeconds
          token = @generateSig keyTime

          controller.validateToken token, @constructor.fixture_api_key, @constructor.fixture_api_secret, ( err, token ) =>
            @isNull err, "No error for a token #{ validSeconds } out."
            @ok token

            cb()

    # these ones should fail as they fall out of the correct window
    for validSeconds in [ -4, 4, -5, 5, -6, 6, -7, 7 ]
      do( validSeconds ) =>
        all.push ( cb ) =>
          keyTime = now + validSeconds
          token = @generateSig keyTime

          controller.validateToken token, @constructor.fixture_api_key, @constructor.fixture_api_secret, ( err, token ) =>
            @ok err, "Error for a token #{ validSeconds } out."

            @match err.message, /Invalid signature/
            @equal err.name, "AppError"

            cb()

    async.series all, ( err ) =>
      @isNull err

      done 39

  "test signatures and expiary times": ( done ) ->
    stub = @stubCatchall 200, "{}",
      "Content-Type": "application/json"

    tests = []

    tests.push ( cb ) =>
      @GET { path: "/?api_key=1234", host: "facebook.api.localhost" }, ( err, response ) =>
        @isNull err

        response.parseJson ( json ) =>
          @ok err = json.error
          @equal err.type, "KeyError"
          @equal err.message, "A signature is required for this API."

          cb()

    tests.push ( cb ) =>
      @GET { path: "/?api_key=1234&api_sig=5678", host: "facebook.api.localhost" }, ( err, response ) =>
        @isNull err

        response.parseJson ( json ) =>
          @ok err = json.error
          @equal err.type, "KeyError"
          @match err.message, /Invalid signature/

          cb()

    tests.push ( cb ) =>
      date = Math.floor( Date.now() / 1000 ).toString()

      md5 = crypto.createHash "md5"
      md5.update @constructor.fixture_api_secret
      md5.update date
      md5.update @constructor.fixture_api_key

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

      done 12
