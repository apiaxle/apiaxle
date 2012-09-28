async = require "async"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.ApiControllerTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "test GET a valid api": ( done ) ->
    # now try and get it
    @GET path: "/v1/api/1234", ( err, res ) =>
      @isNull err
      res.parseJson ( json ) =>
        @ok 1

        done 1

  "test GET keys for a valid api": ( done ) ->
    # now try and get it
    @GET path: "/v1/api/123/keys/0/10", ( err, res ) =>
      @isNull err
      res.parseJson ( json ) =>
        @ok 1

        done 1

  "test GET a non-existant api": ( done ) ->
    # now try and get it
    @GET path: "/v1/api/1234", ( err, res ) =>
      @isNull err
      @equal res.statusCode, 404

      res.parseJson ( json ) =>
        @ok json.error
        @equal json.error.type, "NotFoundError"

        done 4

  "test GET a non-existant api": ( done ) ->
    # now try and get it
    @GET path: "/v1/api/1234", ( err, res ) =>
      @isNull err
      @equal res.statusCode, 404

      res.parseJson ( json ) =>
        @ok json.error
        @equal json.error.type, "NotFoundError"

        done 4

  "test POST a valid api": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        endPoint: "api.example.com"

    @POST options, ( err, res ) =>
      res.parseJson ( json ) =>
        @equal json.apiFormat, "json"

        # check it went in
        @application.model( "api" ).find "1234", ( err, dbApi ) =>
          @equal dbApi.apiFormat, "json"
          @ok dbApi.createdAt

          done 3

  "test POST with an invalid api": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        apiFormat: "json"

    @POST options, ( err, res ) =>
      res.parseJson ( json ) =>
        @ok json.error
        @equal json.error.type, "ValidationError"

        # TODO: this is a terrible message...
        @equal json.error.message, "endPoint: (optional) "

        done 3

  "test PUT with an existing api": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        apiFormat: "xml"
        doesntExist: 1

    @application.model( "api" ).create "1234", endPoint: "hi.com", ( err, origApi ) =>
      @isNull err
      @ok origApi

      @PUT options, ( err, res ) =>
        @equal res.statusCode, 200

        @application.model( "api" ).find "1234", ( err, dbApi ) =>
          @equal dbApi.endPoint, "hi.com"
          @equal dbApi.apiFormat, "xml"

          # we shouldn't have added the superfluous field
          @equal dbApi.doesntExist?, false

          done 6

  "test PUT with a bad structure": ( done ) ->
    @application.model( "api" ).create "1234", endPoint: "hi.com", ( err, origApi ) =>
      @isNull err
      @ok origApi

      options =
        path: "/v1/api/1234"
        headers:
          "Content-Type": "application/json"
        data: JSON.stringify
          endPointTimeout: "txt"

      @PUT options, ( err, res ) =>
        @equal res.statusCode, 400

        res.parseJson ( json ) =>
          @ok json
          @equal json.error.type, "ValidationError"

          done 5

  "test DELETE": ( done ) ->
    @application.model( "api" ).create "1234", endPoint: "hi.com", ( err, origApi ) =>
      @isNull err
      @ok origApi

      @DELETE path: "/v1/api/1234", ( err, res ) =>
        @equal res.statusCode, 200

        @application.model( "api" ).find "1234", ( err, dbApi ) =>
          @isNull err
          @isNull dbApi

          done 5
