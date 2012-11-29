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

        done 2

  "test GET keys for a valid api": ( done ) ->
    # now try and get it
    @GET path: "/v1/api/123/keys/0/10", ( err, res ) =>
      @isNull err
      res.parseJson ( json ) =>
        @ok 1

        done 2

  "test GET a non-existant api": ( done ) ->
    # now try and get it
    @GET path: "/v1/api/1234", ( err, res ) =>
      @isNull err
      @equal res.statusCode, 404

      res.parseJson ( json ) =>
        @ok json.results.error
        @equal json.results.error.type, "NotFoundError"

        done 4

  "test GET a non-existant api": ( done ) ->
    # now try and get it
    @GET path: "/v1/api/1234", ( err, res ) =>
      @isNull err
      @equal res.statusCode, 404

      res.parseJson ( json ) =>
        @ok json.results.error
        @equal json.results.error.type, "NotFoundError"

        done 4

  "test POST an invalid regexp for an API": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        endPoint: "api.example.com"
        extractKeyRegex: "hello(" # invalid

    @POST options, ( err, res ) =>
      @isNull err
    
      @equal res.statusCode, 400

      res.parseJson ( json ) =>
        @equal json.meta.status_code, 400
        @match json.results.error.message, /Invalid regular expression/

        done 4

  "test POST a valid api but no content-type header": ( done ) ->
    options =
      path: "/v1/api/1234"
      data: JSON.stringify
        endPoint: "api.example.com"

    @POST options, ( err, res ) =>
      @isNull err

      res.parseJson ( json ) =>
        @ok json.results.error
        @equal json.results.error.type, "InvalidContentType"
        @equal json.results.error.message, "Content-type is a required header."

        done 4

  "test POST a valid api but an invalid content-type header": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "text/json"
      data: JSON.stringify
        endPoint: "api.example.com"

    @POST options, ( err, res ) =>
      @isNull err

      res.parseJson ( json ) =>
        @ok json.results.error
        @equal json.results.error.type, "InvalidContentType"
        @equal json.results.error.message, "text/json is not a supported content type."

        done 4

  "test POST a valid api": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        endPoint: "api.example.com"

    @POST options, ( err, res ) =>
      @isNull err
      @equal res.statusCode, 200

      res.parseJson ( json ) =>
        @isUndefined json.results.error
        @equal json.results.apiFormat, "json"

        # check it went in
        @application.model( "apiFactory" ).find "1234", ( err, dbApi ) =>
          @equal dbApi.data.apiFormat, "json"
          @ok dbApi.data.createdAt

          done 6

  "test POST with an invalid api": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        apiFormat: "json"

    @POST options, ( err, res ) =>
      @isNull err
      @equal res.statusCode, 400

      res.parseJson ( json ) =>
        @ok json.results.error
        @equal json.results.error.type, "ValidationError"

        # TODO: this is a terrible message...
        @equal json.results.error.message, "endPoint: (optional) "

        done 5

  "test PUT with an existing api": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        apiFormat: "xml"
        doesntExist: 1

    @application.model( "apiFactory" ).create "1234", endPoint: "hi.com", ( err, origApi ) =>
      @isNull err
      @ok origApi

      @PUT options, ( err, res ) =>
        @isNull err
        @equal res.statusCode, 200

        @application.model( "apiFactory" ).find "1234", ( err, dbApi ) =>
          @equal dbApi.data.endPoint, "hi.com"
          @equal dbApi.data.apiFormat, "xml"

          # we shouldn't have added the superfluous field
          @equal dbApi.data.doesntExist?, false

          done 7

  "test PUT with a bad structure": ( done ) ->
    @application.model( "apiFactory" ).create "1234", endPoint: "hi.com", ( err, origApi ) =>
      @isNull err
      @ok origApi

      options =
        path: "/v1/api/1234"
        headers:
          "Content-Type": "application/json"
        data: JSON.stringify
          endPointTimeout: "txt"

      @PUT options, ( err, res ) =>
        @isNull err
        @equal res.statusCode, 400

        res.parseJson ( json ) =>
          @ok json
          @equal json.results.error.type, "ValidationError"

          done 6

  "test DELETE with invalid API": ( done ) ->
    @DELETE path: "/v1/api/1234", ( err, res ) =>
      @equal res.statusCode, 404

      res.parseJson ( json ) =>
        @ok json.results.error
        @ok json.meta.status_code, 404

        @equal json.results.error.message, "1234 not found."
        @equal json.results.error.type, "NotFoundError"

        done 5

  "test DELETE": ( done ) ->
    @application.model( "apiFactory" ).create "1234", endPoint: "hi.com", ( err, origApi ) =>
      @isNull err
      @ok origApi

      @DELETE path: "/v1/api/1234", ( err, res ) =>
        @isNull err
        @equal res.statusCode, 200

        res.parseJson ( json ) =>
          # no error
          @equal json.results.error?, false

          # just returns true
          @equal json.results, true
          @equal json.meta.status_code, 200

          # confirm it's out of the database
          @application.model( "apiFactory" ).find "1234", ( err, dbApi ) =>
            @isNull err
            @isNull dbApi

            done 9

  "test GET list apis without resolution": ( done ) ->
    # create 11 apis
    fixtures = []
    model = @application.model( "apiFactory" )

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          model.create "api_#{i}", endPoint: "api_#{i}.com", cb

    async.series fixtures, ( err, newApis ) =>
      @isNull err

      @GET path: "/v1/api/list/1/12", ( err, response ) =>
        @isNull err

        response.parseJson ( json ) =>
          @ok json
          @equal json.results.length, 10
          done 4

  "test list apis with resolution": ( done ) ->
    # create 11 apis
    fixtures = []

    model = @application.model( "apiFactory" )

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          options =
            globalCache: i
            apiFormat:   "json"
            endPoint:    "api_#{i}.com"

          model.create "api_#{i}", options, cb

    async.parallel fixtures, ( err, newApis ) =>
      @isNull err

      @GET path: "/v1/api/list/0/12?resolve=true", ( err, response ) =>
        @isNull err

        response.parseJson ( json ) =>
          @ok json

          for i in [ 0..9 ]
            name = "api_#{i}"

            @ok json.results[ name ]
            @equal json.results[ name ].globalCache, i
            @equal json.results[ name ].endPoint, "api_#{i}.com"

          done 33
