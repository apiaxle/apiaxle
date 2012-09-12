async = require "async"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.StatsControllerTest extends ApiaxleTest
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

      @application.model( "apiKey" ).create "1234", keyOptions, ( err ) ->
        done()

  "test all counts": ( done ) ->
    model = @application.model "counters"

    hits = []

    # 2011-12-04
    clock = @getClock 1323892867000

    hits.push ( cb ) => model.apiHit "1234", 400, cb
    hits.push ( cb ) => model.apiHit "1234", 400, cb
    hits.push ( cb ) => model.apiHit "1234", 400, cb

    hits.push ( cb ) => model.apiHit "1234", 200, cb
    hits.push ( cb ) => model.apiHit "1234", 200, cb

    hits.push ( cb ) => model.apiHit "1234", 404, cb

    async.parallel hits, ( err, results ) =>
      @isNull err

      @GET path: "/v1/stats/1234/all", ( err, res ) =>
        @isNull err

        shouldHave =
          "200":
            "2011-12-4": "2"
            "2011-12": "2"
            "2011": "2"
          "400":
            "2011-12-4": "3"
            "2011-12": "3"
            "2011": "3"
          "404":
            "2011-12-4": "1"
            "2011-12": "1"
            "2011": "1"

        res.parseJson ( json ) =>
          @ok json
          @deepEqual json, shouldHave

          # now again but a couple of days later
          newHits = []

          # 2011-12-06
          clock.addDays 2

          newHits.push ( cb ) => model.apiHit "1234", 400, cb
          newHits.push ( cb ) => model.apiHit "1234", 400, cb
          newHits.push ( cb ) => model.apiHit "1234", 200, cb

          async.parallel newHits, ( err ) =>
            @GET  path: "/v1/stats/1234/all", ( err, res ) =>
              @isNull err

              shouldHave =
                "200":
                  "2011-12-4": "2"
                  "2011-12-6": "1"
                  "2011-12": "3"
                  "2011": "3"
                "400":
                  "2011-12-6": "2"
                  "2011-12-4": "3"
                  "2011-12": "5"
                  "2011": "5"
                "404":
                  "2011-12-4": "1"
                  "2011-12": "1"
                  "2011": "1"

              res.parseJson ( json ) =>
                @ok json
                @deepEqual json, shouldHave

              done 7
