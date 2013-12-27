# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
async = require "async"

{ ValidationError } = require "../lib/error"
{ FakeAppTest }     = require "./apiaxle_base"

class exports.ApiTest extends FakeAppTest
  @empty_db_on_setup = true

  "test creating fixtures with #create": ( done ) ->
    structure =
      api:
        facebook:
          endPoint: "graph.facebook.com"
        twitter:
          endPoint: "example.com"
      key:
        1234:
          forApis: [ "facebook" ]
          qpd: 13
          qps: 14
        5678:
          forApis: [ "twitter" ]

    console.log( 1 )

    @fixtures.create structure, ( err, results ) =>
      @ok not err
      @ok results
      @equal results.length, 4

      console.log( 2 )

      all_tests = []

      all_tests.push ( cb ) =>
        console.log( 3 )

        @app.model( "apifactory" ).find [ "facebook" ], ( err, results ) =>
          console.log( 3.1 )

          @ok not err
          @ok results.facebook
          @equal results.facebook.data.endPoint, "graph.facebook.com"

          cb()

      all_tests.push ( cb ) =>
        console.log( 4 )

        @app.model( "apifactory" ).find [ "twitter" ], ( err, results ) =>
          console.log( 4.1 )

          @ok not err
          @ok results.twitter

          cb()

      all_tests.push ( cb ) =>
        console.log( 5 )

        @app.model( "keyfactory" ).find [ "1234" ], ( err, results ) =>
          console.log( 5.1 )

          @ok not err
          @ok results["1234"]

          cb()

      async.parallel all_tests, ( err ) -> done 10