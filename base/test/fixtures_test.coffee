async = require "async"

{ ValidationError } = require "../lib/error"
{ FakeAppTest }     = require "./apiaxle-base"

class exports.ApiTest extends FakeAppTest
  @empty_db_on_setup = true

  "test creating fixtures with #create": ( done ) ->
    structure =
      api:
        facebook:
          endPoint: "graph.facebook.com"
        twitter: {}
      key:
        1234:
          forApis: [ "facebook" ]
          qpd: 13
          qps: 14
        5678:
          forApis: [ "twitter" ]

    @fixtures.create structure, ( err, results ) =>
      @isNull err
      @ok results
      @equal results.length, 4

      all_tests = []

      all_tests.push ( cb ) =>
        @app.model( "apiFactory" ).find "facebook", ( err, api ) =>
          @isNull err
          @ok api
          @equal api.data.endPoint, "graph.facebook.com"

          cb()

      all_tests.push ( cb ) =>
        @app.model( "apiFactory" ).find "twitter", ( err, api ) =>
          @isNull err
          @ok api

          cb()

      all_tests.push ( cb ) =>
        @app.model( "keyFactory" ).find "1234", ( err, key ) =>
          @isNull err
          @ok key

          cb()

      async.parallel all_tests, ( err ) -> done 10