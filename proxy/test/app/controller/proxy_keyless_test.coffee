# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
nock = require "nock"

{ ApiaxleTest } = require "../../apiaxle"

class exports.CatchallKeylessTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup API": ( done ) ->
    fixture =
      api:
        facebook:
          endPoint: "example.com"
          allowKeylessUse: true
          keylessQps: 4
          keylessQpd: 12

    @fixtures.create fixture, ( err, [ @api ] ) -> done()

  "test a keyless hit": ( done ) ->
    requestOptions =
      path: "/"
      host: "facebook.api.localhost"

    @stubDns { "facebook.api.localhost": "127.0.0.1" }
    scope1 = nock( "http://example.com" )
      .get( "/" )
      .once()
      .reply( 200, "{}" )

    @GET requestOptions, ( err, response ) =>
      @ok not err
      @ok scope1.isDone()

      response.parseJson ( err, json ) =>
        @ok not json.results?.error?

        model = @app.model( "keyfactory" )

        key_name = "ip-facebook-127.0.0.1"
        model.find [ key_name ], ( err, results ) =>
          @ok not err
          @ok dbKey = results[key_name]

          # correct qps, qpd
          @equal dbKey.data.qps, 4
          @equal dbKey.data.qpd, 12

          @equal response.headers["x-apiaxleproxy-qps-left"], 3
          @equal response.headers["x-apiaxleproxy-qpd-left"], 11

          done 9
