# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
crypto = require "crypto"
async = require "async"
nock = require "nock"

{ ApiaxleTest } = require "../../apiaxle"

class exports.CatchallSigTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup api": ( done ) ->
    fixtures =
      api:
        facebook:
          apiFormat: "json"
          endPoint: "doesntresolve.blah"
      key:
        1234:
          sharedSecret: "bob-the-builder"
          forApis: [ "facebook" ]

    @fixtures.create fixtures, done

  generateSig: ( epoch ) ->
    date = Math.floor( epoch ).toString()

    hmac = crypto.createHmac "sha1", "bob-the-builder"
    hmac.update date
    hmac.update "1234"

    return hmac.digest "hex"

  "test #validateToken": ( done ) ->
    # pause time and get the current epoch
    clock = @getClock()
    now = Math.floor( Date.now() / 1000 )

    all = []

    # all of these should be fine given the three second window
    for validSeconds in [ 0, -1, -2, -3, 1, 2, 3 ]
      do( validSeconds ) =>
        all.push ( cb ) =>
          keyTime = now + validSeconds
          token = @generateSig keyTime

          @app.validateToken 3, token, "1234", "bob-the-builder", ( err, token ) =>
            @ok not err
            @ok token

            cb()

    # these ones should fail as they fall out of the correct window
    for validSeconds in [ -4, 4, -5, 5, -6, 6, -7, 7 ]
      do( validSeconds ) =>
        all.push ( cb ) =>
          keyTime = now + validSeconds
          token = @generateSig keyTime

          @app.validateToken 3, token, "1234", "bob-the-builder", ( err ) =>
            @ok err,
              "There should be an error for a token that's #{ validSeconds } out."

            @equal err.message, "Invalid signature \(got #{ token }\)."
            @equal err.name, "KeyError"

            cb()

    async.series all, ( err ) =>
      @ok not err

      done 39

  "test signatures and expiry times": ( done ) ->
    @stubDns { "facebook.api.localhost": "127.0.0.1" }

    tests = []
    tests.push ( cb ) =>
      @GET { path: "/?api_key=1234", host: "facebook.api.localhost" }, ( err, response ) =>
        @ok not err

        response.parseJson ( err, json ) =>
          @ok not err

          @ok jsonerr = json.results.error

          @equal jsonerr.type, "KeyError"
          @equal jsonerr.message, "A signature is required for this API."

          cb()

    tests.push ( cb ) =>
      options =
        path: "/?api_key=1234&api_sig=5678"
        host: "facebook.api.localhost"

      @GET options, ( err, response ) =>
        @ok not err

        response.parseJson ( err, json ) =>
          @ok not err

          @ok jsonerr = json.results.error

          @ok jsonerr
          @equal jsonerr.type, "KeyError"
          @equal jsonerr.message, "Invalid signature (got 5678)."

          cb()

    tests.push ( cb ) =>
      date = Math.floor( Date.now() / 1000 ).toString()

      validSig = @generateSig Math.floor( Date.now() / 1000 )

      httpOptions =
        path: "/?api_key=1234&api_sig=#{validSig}"
        host: "facebook.api.localhost"

      # mock out the http call just incase
      scope = nock( "http://doesntresolve.blah" )
        .get( "/" )
        .once()
        .reply( 200, JSON.stringify( { url: "HI" }) )

      @GET httpOptions, ( err, response ) =>
        @ok not err
        @ok scope.isDone()

        response.parseJson ( err, json ) =>
          @ok not err
          @ok not json.results?.error?

          @noMatch json.url, /api_(axle)?_sig/

          cb()

    async.series tests, ( err ) =>
      @ok not err

      done 17
