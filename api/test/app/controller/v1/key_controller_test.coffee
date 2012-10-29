async = require "async"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.KeyControllerTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup Api": ( done ) ->
    details =
      endPoint: "api.twitter.com"

    @keyModel = @application.model( "key" )

    @application.model( "api" ).create "twitter", details, ( err, @newApi ) ->
      done()

  "test GET a valid key": ( done ) ->
    @keyModel.create "1234", forApi: "twitter", ( err, newKey ) =>
      @isNull err
      @ok newKey

      # now try and get it
      @GET path: "/v1/key/1234", ( err, res ) =>
        res.parseJson ( json ) =>
          @isNumber parseInt( json.results.qps )
          @isNumber parseInt( json.results.qpd )

          done 4

  "test GET a non-existant key": ( done ) ->
    # now try and get it
    @GET path: "/v1/key/1234", ( err, res ) =>
      @isNull err
      @equal res.statusCode, 404

      res.parseJson ( json ) =>
        @ok json.results.error
        @equal json.results.error.type, "NotFoundError"

        done 4

  "test POST a valid key": ( done ) ->
    options =
      path: "/v1/key/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        forApi: "twitter"
        qps: 1
        qpd: 100

    @POST options, ( err, res ) =>
      res.parseJson ( json ) =>
        @equal json.results.qps, "1"
        @equal json.results.qpd, "100"
        @equal json.results.forApi, "twitter"

        # check it went in
        @keyModel.find "1234", ( err, dbKey ) =>
          @isNull err

          @equal dbKey.qps, "1"
          @equal dbKey.qpd, "100"
          @equal dbKey.forApi, "twitter"
          @ok dbKey.createdAt

          @application.model("api").getKeys "twitter", 0, 10, (err, keys) =>
            @equal keys[0], "1234"
            done 9

  "test POST with an invalid key": ( done ) ->
    options =
      path: "/v1/key/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        forApi: "twitter"
        qps: "invalid"
        qpd: 100

    @POST options, ( err, res ) =>
      res.parseJson ( json ) =>
        @ok json.results.error
        @equal json.results.error.type, "ValidationError"
        @equal json.results.error.message, "qps: (type) Invalid type"

        done 3

  "test PUT with an existing key": ( done ) ->
    options =
      path: "/v1/key/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        forApi: "twitter"
        qps: 30
        qpd: 1000

    @keyModel.create "1234", forApi: "twitter", ( err, origKey ) =>
      @isNull err
      @ok origKey

      @PUT options, ( err, res ) =>
        @equal res.statusCode, 200

        @keyModel.find "1234", ( err, dbKey ) =>
          @equal dbKey.qps, "30"
          @equal dbKey.qpd, "1000"

          done 5

  "test PUT with a bad structure": ( done ) ->
    options =
      path: "/v1/key/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        forApi: "twitter"
        qps: "hi"     # invalid
        qpd: 1000

    @keyModel.create "1234", forApi: "twitter", ( err, origKey ) =>
      @isNull err
      @ok origKey

      @PUT options, ( err, res ) =>
        @equal res.statusCode, 400

        res.parseJson ( json ) =>
          @ok json
          @equal json.results.error.type, "ValidationError"

          done 5

  "test DELETE with invalid KEY": ( done ) ->
    @DELETE path: "/v1/key/1234", ( err, res ) =>
      @equal res.statusCode, 404

      res.parseJson ( json ) =>
        @ok json.results.error
        @ok json.meta.status_code, 404

        @equal json.results.error.message, "1234 not found."
        @equal json.results.error.type, "NotFoundError"

        done 5

  "test DELETE with valid key": ( done ) ->
    @keyModel.create "1234", forApi: "twitter", ( err, origKey ) =>
      @isNull err
      @ok origKey

      @DELETE path: "/v1/key/1234", ( err, res ) =>
        @isNull err
        @equal res.statusCode, 200

        res.parseJson ( json ) =>
          # no error
          @equal json.results.error?, false

          # just returns true
          @equal json.results, true
          @equal json.meta.status_code, 200

          # confirm it's out of the database
          @application.model( "key" ).find "1234", ( err, dbKey ) =>
            @isNull err
            @isNull dbKey

            done 9

  "test get key range without resolution": ( done ) ->
    # create 11 keys
    fixtures = []

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          @keyModel.create "key_#{i}", forApi: "twitter", cb

    async.series fixtures, ( err, newKeys ) =>
      @isNull err

      @GET path: "/v1/key/list/1/12", ( err, response ) =>
        @isNull err

        response.parseJson ( json ) =>
          @ok json
          @equal json.results.length, 10

          done 4


  "test get key range with resolution": ( done ) ->
    # create 11 keys
    fixtures = []

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          @keyModel.create "key_#{i}", forApi: "twitter", qps: i, qpd: i, cb

    async.parallel fixtures, ( err, newKeys ) =>
      @isNull err

      @GET path: "/v1/key/list/0/12?resolve=true", ( err, response ) =>
        @isNull err

        response.parseJson ( json ) =>
          @ok json

          for i in [ 0..9 ]
            name = "key_#{i}"

            @ok json.results[ name ]
            @equal json.results[ name ].qpd, i
            @equal json.results[ name ].qps, i
            @equal json.results[ name ].forApi, "twitter"

          done 43

class exports.KeyStatsTest extends ApiaxleTest
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

      @GET path: "/v1/key/1234/stats", ( err, res ) =>
        @isNull err

        shouldHave =
          meta:
            version: 1
            status_code: 200
          results:
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
            @GET  path: "/v1/key/1234/stats", ( err, res ) =>
              @isNull err

              shouldHave =
                meta:
                  version: 1
                  status_code: 200
                results:
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
