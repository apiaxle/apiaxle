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
        @application.model( "api" ).find "1234", ( err, dbApi ) =>
          @equal dbApi.apiFormat, "json"
          @ok dbApi.createdAt

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

    @fixtures.createApi "1234", endPoint: "hi.com", ( err, origApi ) =>
      @isNull err
      @ok origApi

      @PUT options, ( err, res ) =>
        @isNull err
        @equal res.statusCode, 200

        @application.model( "api" ).find "1234", ( err, dbApi ) =>
          @equal dbApi.endPoint, "hi.com"
          @equal dbApi.apiFormat, "xml"

          # we shouldn't have added the superfluous field
          @equal dbApi.doesntExist?, false

          done 7

  "test PUT with a bad structure": ( done ) ->
    @fixtures.createApi "1234", endPoint: "hi.com", ( err, origApi ) =>
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
    @fixtures.createApi "1234", endPoint: "hi.com", ( err, origApi ) =>
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
          @application.model( "api" ).find "1234", ( err, dbApi ) =>
            @isNull err
            @isNull dbApi

            done 9
  "test GET list apis without resolution": ( done ) ->
    # create 11 apis
    fixtures = []
    @apiModel = @application.model( "api" )

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          @apiModel.create "api_#{i}", endPoint: "api_#{i}.com", cb

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

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          options =
            globalCache: i
            apiFormat:   "json"
            endPoint:    "api_#{i}.com"

          @apiModel.create "api_#{i}", options, cb

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

class exports.ApiStatsTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup api and key": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "json"

    # we create the API
    @application.model( "api" ).create "facebook", apiOptions, ( err ) =>
      keyOptions =
        forApi: "facebook"

      @application.model( "key" ).create "1234", keyOptions, ( err ) ->
        done()

  "test GET all counts with range": ( done ) ->
    model = @application.model "counters"

    hits = []

    # Wed, December 14th 2011, 20:01
    clock = @getClock 1323892867000
    hits.push ( cb ) => model.apiHit "facebook", "1234", 200, cb
    hits.push ( cb ) => model.apiHit "facebook", "1234", 400, cb
    hits.push ( cb ) => model.apiHit "facebook", "1234", 400, cb

    async.parallel hits, ( err, results ) =>
      @isNull err

      @GET path: "/v1/api/facebook/stats?from-date=2011-12-10&to-date=2011-12-16", ( err, res ) =>
        @isNull err

        shouldHave =
          meta:
            version: 1
            status_code: 200
          results:
            "200":
               "2011-12-14": "1"
               "2011-12-14 20": "1"
               "2011-12-14 20:1": "1"
             "400":
               "2011-12-14": "2"
               "2011-12-14 20": "2"
               "2011-12-14 20:1": "2"

        res.parseJson ( json ) =>
          @ok json
          @deepEqual json, shouldHave

          # now again but a couple of days later
          newHits = []

          # Fri, 16 Dec 2011 20:01:07 GMT
          clock.addDays 2

          newHits.push ( cb ) => model.apiHit "facebook", "1234", 400, cb
          newHits.push ( cb ) => model.apiHit "facebook", "1234", 400, cb
          newHits.push ( cb ) => model.apiHit "facebook", "1234", 200, cb

          async.parallel newHits, ( err ) =>
            path = "/v1/api/facebook/stats?from-date=2011-12-10&to-date=2011-12-16"
            @GET path: path, ( err, res ) =>
              @isNull err

              shouldHave =
                meta:
                  version: 1
                  status_code: 200
                results:
                  "200":
                    "2011-12-14": "1"
                    "2011-12-14 20": "1",
                    "2011-12-14 20:1": "1"
                    "2011-12-16": "1"
                    "2011-12-16 20": "1",
                    "2011-12-16 20:1": "1"
                  "400":
                    "2011-12-14": "2"
                    "2011-12-14 20": "2"
                    "2011-12-14 20:1": "2"
                    "2011-12-16": "2",
                    "2011-12-16 20": "2",
                    "2011-12-16 20:1": "2"

              res.parseJson ( json ) =>
                @ok json
                @deepEqual json, shouldHave

              done 7


  "test GET all counts": ( done ) ->
    model = @application.model "counters"

    hits = []

    # Wed, 14 Dec 2011 20:01:07 GMT
    clock = @getClock 1323892867000

    hits.push ( cb ) => model.apiHit "facebook", "1234", 400, cb
    hits.push ( cb ) => model.apiHit "facebook", "5678", 400, cb
    hits.push ( cb ) => model.apiHit "facebook", "5678", 400, cb

    hits.push ( cb ) => model.apiHit "facebook", "1234", 200, cb
    hits.push ( cb ) => model.apiHit "facebook", "5678", 200, cb

    hits.push ( cb ) => model.apiHit "facebook", "1234", 404, cb

    async.parallel hits, ( err, results ) =>
      @isNull err

      @GET path: "/v1/api/facebook/stats", ( err, res ) =>
        @isNull err

        shouldHave =
          meta:
            version: 1
            status_code: 200
          results:
            "200":
               "2011": "2"
               "2011-12-14": "2"
               "2011-12": "2"
               "2011-12-14 20": "2"
               "2011-12-14 20:1": "2"
             "400":
               "2011": "3"
               "2011-12-14": "3"
               "2011-12": "3"
               "2011-12-14 20": "3"
               "2011-12-14 20:1": "3"
             "404":
               "2011": "1"
               "2011-12-14": "1"
               "2011-12": "1"
               "2011-12-14 20": "1"
               "2011-12-14 20:1": "1"

        res.parseJson ( json ) =>
          @ok json
          @deepEqual json, shouldHave

          # now again but a couple of days later
          newHits = []

          # Fri, 16 Dec 2011 20:01:07 GMT
          clock.addDays 2

          newHits.push ( cb ) => model.apiHit "facebook", "1234", 400, cb
          newHits.push ( cb ) => model.apiHit "facebook", "1234", 400, cb
          newHits.push ( cb ) => model.apiHit "facebook", "1234", 200, cb

          async.parallel newHits, ( err ) =>
            @GET  path: "/v1/api/facebook/stats", ( err, res ) =>
              @isNull err

              shouldHave =
                meta:
                  version: 1
                  status_code: 200
                results:
                  "200":
                    "2011": "3"
                    "2011-12-14": "2"
                    "2011-12": "3"
                    "2011-12-14 20": "2",
                    "2011-12-14 20:1": "2"
                    "2011-12-16": "1"
                    "2011-12-16 20": "1",
                    "2011-12-16 20:1": "1"
                  "400":
                    "2011": "5"
                    "2011-12-14": "3"
                    "2011-12": "5"
                    "2011-12-14 20": "3"
                    "2011-12-14 20:1": "3"
                    "2011-12-16": "2",
                    "2011-12-16 20": "2",
                    "2011-12-16 20:1": "2"
                  "404":
                    "2011": "1"
                    "2011-12-14": "1"
                    "2011-12": "1"
                    "2011-12-14 20": "1"
                    "2011-12-14 20:1": "1"

              res.parseJson ( json ) =>
                @ok json
                @deepEqual json, shouldHave

              done 7
