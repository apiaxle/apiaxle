_     = require "underscore"
async = require "async"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.ApiControllerTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "test linkkey with invalid api": ( done ) ->
    @PUT path: "/v1/api/bob/linkkey/bill", ( err, res ) =>
      @isNull err

      res.parseJson ( err, json ) =>
        @isNull err
        @equal json.results.error.message, "Api 'bob' not found."

        done 3

  "test linkkey": ( done ) ->
    fixture =
      api:
        bob: {}
        twitter: {}
      key:
        bill:
          qps: 201

    @fixtures.create fixture, ( err, [ dbBob ] ) =>
      @isNull err

      dbBob.getKeys 0, 20, ( err, keys ) =>
        @isNull err
        @deepEqual keys, []

        @PUT path: "/v1/api/bob/linkkey/bill", ( err, res ) =>
          @isNull err

          res.parseJson ( err, json ) =>
            @isNull err
            @equal json.results.qps, 201

            dbBob.getKeys 0, 20, ( err, keys ) =>
              @isNull err
              @deepEqual keys, [ "bill" ]

              done 8

  "test GET a valid api": ( done ) ->
    # now try and get it
    @GET path: "/v1/api/1234", ( err, res ) =>
      @isNull err
      res.parseJson ( err, json ) =>
        @isNull err
        @ok json

        done 3

  "test GET keys for a valid api": ( done ) ->
    fixture =
      api:
        twitter: {}
        facebook: {}
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
      @isNull err

      base_call = "/v1/api/twitter/keys?from=0&to=9"

      all_tests = []

      # without resolution
      all_tests.push ( cb ) =>
        @GET path: base_call, ( err, res ) =>
          @isNull err

          res.parseJson ( err, json ) =>
            @deepEqual json.results, [ "hello", "5678", "1234" ]
            cb()

      # with resolution
      all_tests.push ( cb ) =>
        @GET path: "#{ base_call }&resolve=true", ( err, res ) =>
          @isNull err

          res.parseJson ( err, json ) =>
            @equal json.results[ "1234" ].qpd, 172800
            @equal json.results[ "5678" ].qpd, 172800
            @equal json.results[ "hello" ].qpd, 172800

            cb()

      async.series all_tests, ( err ) =>
        @isNull err

        done 8

  "test GET a non-existant api": ( done ) ->
    # now try and get it
    @GET path: "/v1/api/1234", ( err, res ) =>
      @isNull err
      @equal res.statusCode, 404

      res.parseJson ( err, json ) =>
        @isNull err
        @ok json.results.error
        @equal json.results.error.type, "ApiNotFoundError"

        done 5

  "test GET a non-existant api": ( done ) ->
    # now try and get it
    @GET path: "/v1/api/1234", ( err, res ) =>
      @isNull err
      @equal res.statusCode, 404

      res.parseJson ( err, json ) =>
        @isNull err
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
      @isNull err
      @equal res.statusCode, 400

      res.parseJson ( err, json ) =>
        @isNull err
        @equal json.meta.status_code, 400
        @match json.results.error.message, /Invalid regular expression/

        done 5

  "test POST a valid api but no content-type header": ( done ) ->
    options =
      path: "/v1/api/1234"
      data: JSON.stringify
        endPoint: "api.example.com"

    @POST options, ( err, res ) =>
      @isNull err

      res.parseJson ( err, json ) =>
        @isNull err
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
      @isNull err

      res.parseJson ( err, json ) =>
        @isNull err
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
      @isNull err
      @equal res.statusCode, 200

      res.parseJson ( err, json ) =>
        @isNull err
        @isUndefined json.results.error
        @equal json.results.apiFormat, "json"

        # check it went in
        @app.model( "apiFactory" ).find "1234", ( err, dbApi ) =>
          @equal dbApi.data.apiFormat, "json"
          @ok dbApi.data.createdAt

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
      @isNull err
      @equal res.statusCode, 200

      res.parseJson ( err, json ) =>
        @isUndefined json.results.error
        @equal json.results.apiFormat, "json"

        # check it went in
        @app.model( "apiFactory" ).find "1234", ( err, dbApi ) =>
          @equal dbApi.data.apiFormat, "json"
          @equal dbApi.data.protocol, "https"
          @ok dbApi.data.createdAt

          done 7

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

      res.parseJson ( err, json ) =>
        @isNull err
        @ok json.results.error
        @equal json.results.error.type, "ValidationError"
        @equal json.results.error.message, "endPoint: The ‘endPoint’ property is required."

        done 6

  "test PUT with an existing api": ( done ) ->
    options =
      path: "/v1/api/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        apiFormat: "xml"

    @fixtures.createApi "1234", endPoint: "hi.com", ( err, origApi ) =>
      @isNull err
      @ok origApi

      @PUT options, ( err, res ) =>
        @isNull err
        @equal res.statusCode, 200

        @app.model( "apiFactory" ).find "1234", ( err, dbApi ) =>
          @equal dbApi.data.endPoint, "hi.com"
          @equal dbApi.data.apiFormat, "xml"

          done 6

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

        res.parseJson ( err, json ) =>
          @isNull err
          @ok json
          @equal json.results.error.type, "ValidationError"

          done 7

  "test DELETE with invalid API": ( done ) ->
    @DELETE path: "/v1/api/1234", ( err, res ) =>
      @equal res.statusCode, 404

      res.parseJson ( err, json ) =>
        @isNull err
        @ok json.results.error
        @ok json.meta.status_code, 404

        @equal json.results.error.message, "Api '1234' not found."
        @equal json.results.error.type, "ApiNotFoundError"

        done 6

  "test DELETE": ( done ) ->
    @fixtures.createApi "1234", endPoint: "hi.com", ( err, origApi ) =>
      @isNull err
      @ok origApi

      @DELETE path: "/v1/api/1234", ( err, res ) =>
        @isNull err
        @equal res.statusCode, 200

        res.parseJson ( err, json ) =>
          @isNull err
          # no error
          @equal json.results.error?, false

          # just returns true
          @equal json.results, true
          @equal json.meta.status_code, 200

          # confirm it's out of the database
          @app.model( "apiFactory" ).find "1234", ( err, dbApi ) =>
            @isNull err
            @isNull dbApi

            done 10

  "test list apis without resolution": ( done ) ->
    # create 11 apis
    fixtures = []
    model = @app.model( "apiFactory" )

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          model.create "api_#{i}", endPoint: "api_#{i}.com", cb

    async.series fixtures, ( err, newApis ) =>
      @isNull err

      @GET path: "/v1/apis?from=1&to=12", ( err, response ) =>
        @isNull err

        response.parseJson ( err, json ) =>
          @isNull err
          @ok json
          @equal json.results.length, 10

          done 5

  "test list apis with resolution": ( done ) ->
    # create 11 apis
    fixtures = []

    model = @app.model( "apiFactory" )

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

      @GET path: "/v1/apis?from=0&to=12&resolve=true", ( err, response ) =>
        @isNull err

        response.parseJson ( err, json ) =>
          @isNull err
          @ok json

          for i in [ 0..9 ]
            name = "api_#{i}"

            @ok json.results[ name ]
            @equal json.results[ name ].globalCache, i
            @equal json.results[ name ].endPoint, "api_#{i}.com"

          done 34

class exports.ApiStatsTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup api and key": ( done ) ->
    fixtures =
      api:
        test_stats:
          endPoint:  "graph.facebook.com"
          apiFormat: "json"
      key:
        1234: {}

    @fixtures.create fixtures, done

   "test GET minute stats for API": ( done ) ->
     model = @app.model "stats"
     hits  = []
     # Wed, December 14th 2011, 20:01
     now = ( new Date ).getTime()
     now_seconds = Math.floor( now/1000 )
     clock = @getClock now

     hits.push ( cb ) => model.hit "test_stats", "1234", "uncached", 200, cb
     hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb
     hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb

     async.parallel hits, ( err, results ) =>
       @isNull err
       @GET path: "/v1/api/test_stats/stats?granularity=minutes&from=#{now_seconds}", ( err, res ) =>
         res.parseJson ( err, json ) =>
           @isNull err
           @ok json

           # A little bit complex as the ts may have shifted by 1
           for code, result of json.results.uncached
             @equal code, 200
             for ts, count of result
               @equal count, 1
           for code, result of json.results.cached
             @equal code, 400
             for ts, count of result
               @ok count > 0
           done 7

   "test GET seconds stats for API": ( done ) ->
     model = @app.model "stats"
     hits  = []
     # Wed, December 14th 2011, 20:01
     now = ( new Date ).getTime()
     now_seconds = Math.floor( now/1000 )
     clock = @getClock now

     hits.push ( cb ) => model.hit "test_stats", "1234", "uncached", 200, cb
     hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb
     hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb

     async.parallel hits, ( err, results ) =>
       @isNull err
       @GET path: "/v1/api/test_stats/stats?granularity=seconds&from=#{now_seconds}", ( err, res ) =>
         res.parseJson ( err, json ) =>
           @isNull err
           @ok json

           # A little bit complex as the ts may have shifted by 1
           for code, result of json.results.uncached
             @equal code, 200
             for ts, count of result
               @equal count, 1
           for code, result of json.results.cached
             @equal code, 400
             for ts, count of result
               @ok count > 0
           done 7

   "test invalid granularity input": ( done ) ->
     @GET path: "/v1/api/test_stats/stats?granularity=nanoparsecs", ( err, res ) =>
      @isNull err

      res.parseJson ( err, json ) =>
        @isNull err
        @ok error = json.results.error

        @equal error.message, "Valid granularities are seconds, minutes, hours, days"
        @equal error.type, "InvalidGranularityType"
        @equal res.statusCode, 400
        @equal json.meta.status_code, 400

        done 7
