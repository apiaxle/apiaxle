# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
_     = require "lodash"
async = require "async"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.ApiControllerTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "test linkkey with invalid api": ( done ) ->
    @PUT path: "/v1/api/bob/linkkey/bill", ( err, res ) =>
      @ok not err

      res.parseJson ( err, json ) =>
        @ok not err
        @equal json.results.error.message, "Api 'bob' not found."

        done 3

  "test linkkey": ( done ) ->
    fixture =
      api:
        bob:
          endPoint: "example.com"
        twitter:
          endPoint: "example.com"
      key:
        bill:
          qps: 201

    @fixtures.create fixture, ( err, [ dbBob ] ) =>
      @ok not err

      dbBob.getKeys 0, 20, ( err, keys ) =>
        @ok not err
        @deepEqual keys, []

        @PUT path: "/v1/api/bob/linkkey/bill", ( err, res ) =>
          @ok not err

          res.parseJson ( err, json ) =>
            @ok not err
            @equal json.results.qps, 201

            dbBob.getKeys 0, 20, ( err, keys ) =>
              @ok not err
              @deepEqual keys, [ "bill" ]

              done 8

  "test GET a valid api": ( done ) ->
    # now try and get it
    @GET path: "/v1/api/1234", ( err, res ) =>
      @ok not err
      res.parseJson ( err, json ) =>
        @ok not err
        @ok json

        done 3

  "test GET keys for a valid api": ( done ) ->
    fixture =
      api:
        twitter:
          endPoint: "example.com"
        facebook:
          endPoint: "example.com"
      key:
        1234:
          forApis: [ "twitter" ]
        5678:
          forApis: [ "twitter" ]
        9876:
          forApis: [ "facebook" ]
        hello:
          forApis: [ "facebook", "twitter" ]

    @fixtures.create fixture, ( err ) =>
      @ok not err

      base_call = "/v1/api/twitter/keys?from=0&to=9"

      all_tests = []

      # without resolution
      all_tests.push ( cb ) =>
        @GET path: base_call, ( err, res ) =>
          @ok not err

          res.parseJson ( err, json ) =>
            @deepEqual json.results, [ "hello", "5678", "1234" ]
            cb()

      # with resolution
      all_tests.push ( cb ) =>
        @GET path: "#{ base_call }&resolve=true", ( err, res ) =>
          @ok not err

          res.parseJson ( err, json ) =>
            @equal json.results[ "1234" ].qpd, 172800
            @equal json.results[ "5678" ].qpd, 172800
            @equal json.results[ "hello" ].qpd, 172800

            cb()

      async.series all_tests, ( err ) =>
        @ok not err

        done 8

  "test GET a non-existant api": ( done ) ->
    # now try and get it
    @GET path: "/v1/api/1234", ( err, res ) =>
      @ok not err
      @equal res.statusCode, 404

      res.parseJson ( err, json ) =>
        @ok not err
        @ok json.results.error
        @equal json.results.error.type, "ApiNotFoundError"

        done 5

  "test GET a non-existant api": ( done ) ->
    # now try and get it
    @GET path: "/v1/api/1234", ( err, res ) =>
      @ok not err
      @equal res.statusCode, 404

      res.parseJson ( err, json ) =>
        @ok not err
        @ok json.results.error
        @equal json.results.error.type, "ApiNotFoundError"

        done 5

  "test POST an invalid regexp for an API": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        endPoint: "api.example.com"
        extractKeyRegex: "hello(" # invalid

    @POST options, ( err, res ) =>
      @ok not err
      @equal res.statusCode, 400

      res.parseJson ( err, json ) =>
        @ok not err
        @equal json.meta.status_code, 400
        @match json.results.error.message, /Invalid regular expression/

        done 5

  "test POST a valid api but no content-type header": ( done ) ->
    options =
      path: "/v1/api/1234"
      data: JSON.stringify
        endPoint: "api.example.com"

    @POST options, ( err, res ) =>
      @ok not err

      res.parseJson ( err, json ) =>
        @ok not err
        @ok json.results.error
        @equal json.results.error.type, "InvalidContentType"
        @equal json.results.error.message, "Content-type is a required header."

        done 5

  "test POST a valid api but an invalid content-type header": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "text/json"
      data: JSON.stringify
        endPoint: "api.example.com"

    @POST options, ( err, res ) =>
      @ok not err

      res.parseJson ( err, json ) =>
        @ok not err
        @ok json.results.error
        @equal json.results.error.type, "InvalidContentType"
        @equal json.results.error.message, "text/json is not a supported content type."

        done 5

  "test POST a valid api": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        endPoint: "api.example.com"

    @POST options, ( err, res ) =>
      @ok not err
      @equal res.statusCode, 200

      res.parseJson ( err, json ) =>
        @ok not err
        @isUndefined json.results.error
        @equal json.results.apiFormat, "json"

        # check it went in
        @app.model( "apifactory" ).find [ "1234" ], ( err, results ) =>
          @equal results["1234"].data.apiFormat, "json"
          @ok results["1234"].data.createdAt

          done 7

  "test POST https protocol": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        endPoint: "api.example.com"
        protocol: "https"

    @POST options, ( err, res ) =>
      @ok not err
      @equal res.statusCode, 200

      res.parseJson ( err, json ) =>
        @isUndefined json.results.error
        @equal json.results.apiFormat, "json"

        # check it went in
        @app.model( "apifactory" ).find [ "1234" ], ( err, results ) =>
          @equal results["1234"].data.apiFormat, "json"
          @equal results["1234"].data.protocol, "https"
          @ok results["1234"].data.createdAt
          @equal results["1234"].data.disabled, false

          done 8

  "test POST with an invalid api": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        apiFormat: "json"

    @POST options, ( err, res ) =>
      @ok not err
      @equal res.statusCode, 400

      res.parseJson ( err, json ) =>
        @ok not err
        @ok json.results.error
        @equal json.results.error.type, "ValidationError"
        @equal json.results.error.message, "The ‘endPoint’ property is required."

        done 6

  "test PUT with an existing api": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        apiFormat: "xml"

    @fixtures.createApi "1234", endPoint: "hi.com", ( err, origApi ) =>
      @ok not err
      @ok origApi

      @PUT options, ( err, res ) =>
        @ok not err
        @equal res.statusCode, 200

        res.parseJson ( err, json ) =>
          @ok not err

          @equal json.results.new.apiFormat, "xml"
          @equal json.results.old.apiFormat, "json"

          @app.model( "apifactory" ).find [ "1234" ], ( err, results ) =>
            @equal results["1234"].data.endPoint, "hi.com"
            @equal results["1234"].data.apiFormat, "xml"

            done 9

  "test PUT with a bad structure": ( done ) ->
    @fixtures.createApi "1234", endPoint: "hi.com", ( err, origApi ) =>
      @ok not err
      @ok origApi

      options =
        path: "/v1/api/1234"
        headers:
          "Content-Type": "application/json"
        data: JSON.stringify
          endPointTimeout: "txt"

      @PUT options, ( err, res ) =>
        @ok not err
        @equal res.statusCode, 400

        res.parseJson ( err, json ) =>
          @ok not err
          @ok json
          @equal json.results.error.type, "ValidationError"

          done 7

  "test DELETE with invalid API": ( done ) ->
    @DELETE path: "/v1/api/1234", ( err, res ) =>
      @equal res.statusCode, 404

      res.parseJson ( err, json ) =>
        @ok not err
        @ok json.results.error
        @ok json.meta.status_code, 404

        @equal json.results.error.message, "Api '1234' not found."
        @equal json.results.error.type, "ApiNotFoundError"

        done 6

  "test DELETE": ( done ) ->
    @fixtures.createApi "1234", endPoint: "hi.com", ( err, origApi ) =>
      @ok not err
      @ok origApi

      @DELETE path: "/v1/api/1234", ( err, res ) =>
        @ok not err
        @equal res.statusCode, 200

        res.parseJson ( err, json ) =>
          @ok not err
          # no error
          @equal json.results.error?, false

          # just returns true
          @equal json.results, true
          @equal json.meta.status_code, 200

          # confirm it's out of the database
          @app.model( "apifactory" ).find [ "1234" ], ( err, results ) =>
            @ok not err
            @ok not results["1234"]

            done 10
  "test invalid query params do the right thing": ( done ) ->
    @GET path: "/v1/apis?hello=world", ( err, res ) =>
      @isNull err

      res.parseJson ( err, json ) =>
        @isNull err
        @ok exp = json.results.error
        @equal exp.type, "ValidationError"
        @equal exp.message, "'hello' is not a supported field."

        done 5

  "test 404": ( done ) ->
    @GET path: "/v1/hello", ( err, res ) =>
      @isNull err

      res.parseJson ( err, json ) =>
        @isNull err
        @ok exp = json.results.error
        @equal res.statusCode, 404
        @equal exp.type, "NotFoundError"
        @equal exp.message, "'/v1/hello' not found."

        done 6
