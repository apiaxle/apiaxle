async = require "async"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.KeyControllerTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup Api": ( done ) ->
    fixtures =
      api:
        twitter:
          endPoint: "api.twitter.com"
        facebook: {}

    @fixtures.create fixtures, ( err, [ @newApi ] ) ->
      done()

  "test GET a valid key": ( done ) ->
    @fixtures.createKey "1234", forApis: [ "twitter", "facebook" ], ( err, newKey ) =>
      @isNull err
      @ok newKey

      # now try and get it
      @GET path: "/v1/key/1234", ( err, res ) =>
        res.parseJson ( err, json ) =>
          @isNull err
          @isNumber parseInt( json.results.qps )
          @isNumber parseInt( json.results.qpd )

          @deepEqual json.results.apis, [ "twitter", "facebook" ]

          done 6

  "test GET a non-existant key": ( done ) ->
    # now try and get it
    @GET path: "/v1/key/1234", ( err, res ) =>
      @isNull err
      @equal res.statusCode, 404

      res.parseJson ( err, json ) =>
        @isNull err
        @ok json.results.error
        @equal json.results.error.type, "KeyNotFoundError"

        done 5

  "test POST a valid key": ( done ) ->
    options =
      path: "/v1/key/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        forApis: [ "twitter" ]
        qps: 1
        qpd: 100

    @POST options, ( err, res ) =>
      res.parseJson ( err, json ) =>
        @isNull err
        @equal json.results.qps, "1"
        @equal json.results.qpd, "100"

        # check it went in
        @app.model( "keyFactory" ).find "1234", ( err, dbKey ) =>
          @isNull err

          @equal dbKey.data.qps, "1"
          @equal dbKey.data.qpd, "100"
          @ok dbKey.data.createdAt

          @app.model("apiFactory").find "twitter", ( err, api ) =>
            @isNull err
            @ok api

            api.getKeys 0, 10, ( err, keys ) =>
              @equal keys.length, 1
              @equal keys[0], "1234"

              done 11

  "test POST with an invalid key": ( done ) ->
    options =
      path: "/v1/key/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        forApis: [ "twitter" ]
        qps: "invalid"
        qpd: 100

    @POST options, ( err, res ) =>
      res.parseJson ( err, json ) =>
        @isNull err
        @ok json.results.error
        @equal json.results.error.type, "ValidationError"
        @equal json.results.error.message, "qps: (type) "

        done 4

  "test PUT with an existing key": ( done ) ->
    options =
      path: "/v1/key/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        forApis: [ "twitter" ]
        qps: 30
        qpd: 1000

    @fixtures.createKey "1234", forApis: [ "twitter" ], ( err, origKey ) =>
      @isNull err
      @ok origKey

      @PUT options, ( err, res ) =>
        @equal res.statusCode, 200

        @app.model( "keyFactory" ).find "1234", ( err, dbKey ) =>
          @equal dbKey.data.qps, "30"
          @equal dbKey.data.qpd, "1000"

          done 5

  "test PUT with a bad structure": ( done ) ->
    options =
      path: "/v1/key/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        forApis: [ "twitter" ]
        qps: "hi"     # invalid
        qpd: 1000

    @fixtures.createKey "1234", forApis: [ "twitter" ], ( err, origKey ) =>
      @isNull err
      @ok origKey

      @PUT options, ( err, res ) =>
        @equal res.statusCode, 400

        res.parseJson ( err, json ) =>
          @isNull err
          @ok json
          @equal json.results.error.type, "ValidationError"

          done 6

  "test DELETE with invalid KEY": ( done ) ->
    @DELETE path: "/v1/key/1234", ( err, res ) =>
      @equal res.statusCode, 404

      res.parseJson ( err, json ) =>
        @isNull err
        @ok json.results.error
        @ok json.meta.status_code, 404

        @equal json.results.error.message, "Key '1234' not found."
        @equal json.results.error.type, "KeyNotFoundError"

        done 6

  "test DELETE with valid key": ( done ) ->
    @fixtures.createKey "1234", forApis: [ "twitter" ], ( err, origKey ) =>
      @isNull err
      @ok origKey

      @DELETE path: "/v1/key/1234", ( err, res ) =>
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
          @app.model( "keyFactory" ).find "1234", ( err, dbKey ) =>
            @isNull err
            @isNull dbKey

            done 10

  "test get key range without resolution": ( done ) ->
    # create 11 keys
    fixtures = []

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          @fixtures.createKey "key_#{i}", forApis: [ "twitter" ], cb

    async.series fixtures, ( err, newKeys ) =>
      @isNull err

      @GET path: "/v1/keys?from=1&to=12", ( err, response ) =>
        @isNull err

        response.parseJson ( err, json ) =>
          @isNull err
          @ok json
          @equal json.results.length, 10

          done 5


  "test get key range with resolution": ( done ) ->
    # create 11 keys
    fixtures = []

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          @fixtures.createKey "key_#{i}", forApis: [ "twitter" ], qps: i, qpd: i, cb

    async.parallel fixtures, ( err, newKeys ) =>
      @isNull err

      @GET path: "/v1/keys?from=0&to=12&resolve=true", ( err, response ) =>
        @isNull err

        response.parseJson ( err, json ) =>
          @isNull err
          @ok json

          for i in [ 0..9 ]
            name = "key_#{i}"

            @ok json.results[ name ]
            @equal json.results[ name ].qpd, i
            @equal json.results[ name ].qps, i

          done 34

class exports.KeyStatsTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup api and key": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "json"

    # we create the API
    @fixtures.createApi "facebook", apiOptions, ( err ) =>
      keyOptions =
        forApis: [ "facebook" ]

      @fixtures.createKey "1234", keyOptions, ( err ) ->
        done()

  "test GET hits for Key": ( done ) ->
    model = @app.model "hits"
    hits  = []
    # Wed, December 14th 2011, 20:01
    clock = @getClock 1323892867000
    hits.push ( cb ) => model.hit "facebook", "1234", 200, cb
    hits.push ( cb ) => model.hit "facebook", "1234", 400, cb
    hits.push ( cb ) => model.hit "facebook", "1234", 400, cb

    shouldHave =
      meta:
        version: 1
        status_code: 200
      results:
        "1323892867": "3"

    async.parallel hits, ( err, results ) =>
      @isNull err
      @GET path: "/v1/key/1234/hits", ( err, res ) =>
        @isNull err

        res.parseJson ( err, json ) =>
          @isNull err
          @ok json
          @deepEqual json, shouldHave
          done 5

  "test GET real time hits for Key": ( done ) ->
    model = @app.model "hits"
    hits  = []
    # Wed, December 14th 2011, 20:01
    clock = @getClock 1323892867000
    hits.push ( cb ) => model.hit "facebook", "1234", 200, cb
    hits.push ( cb ) => model.hit "facebook", "1234", 400, cb
    hits.push ( cb ) => model.hit "facebook", "1234", 400, cb

    shouldHave =
      meta:
        version: 1
        status_code: 200
      results: 3

    async.parallel hits, ( err, results ) =>
      @isNull err
      @GET path: "/v1/key/1234/hits/now", ( err, res ) =>
        @isNull err

        res.parseJson ( err, json ) =>
          @isNull err
          @ok json
          @deepEqual json, shouldHave
          done 5

  "test all counts with range": ( done ) ->
    model = @app.model "counters"

    hits = []

    # Wed, December 14th 2011, 20:01
    clock = @getClock 1323892867000
    hits.push ( cb ) => model.apiHit "facebook", "1234", 200, cb
    hits.push ( cb ) => model.apiHit "facebook", "1234", 400, cb
    hits.push ( cb ) => model.apiHit "facebook", "1234", 400, cb

    async.parallel hits, ( err, results ) =>
      @isNull err

      @GET path: "/v1/key/1234/stats?from-date=2011-12-10&to-date=2011-12-16", ( err, res ) =>
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

        res.parseJson ( err, json ) =>
          @isNull err
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
            path = "/v1/key/1234/stats?from-date=2011-12-10&to-date=2011-12-16"
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

              res.parseJson ( err, json ) =>
                @isNull err
                @ok json
                @deepEqual json, shouldHave

              done 9

  "test all counts": ( done ) ->
    model = @app.model "counters"

    hits = []

    # Wed, 14 Dec 2011 20:01:07 GMT
    clock = @getClock 1323892867000

    hits.push ( cb ) => model.apiHit "facebook", "1234", 400, cb
    hits.push ( cb ) => model.apiHit "facebook", "1234", 400, cb
    hits.push ( cb ) => model.apiHit "facebook", "1234", 400, cb

    hits.push ( cb ) => model.apiHit "facebook", "1234", 200, cb
    hits.push ( cb ) => model.apiHit "facebook", "1234", 200, cb

    hits.push ( cb ) => model.apiHit "facebook", "1234", 404, cb

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

        res.parseJson ( err, json ) =>
          @isNull err
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
            @GET  path: "/v1/key/1234/stats", ( err, res ) =>
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

              res.parseJson ( err, json ) =>
                @isNull err
                @ok json
                @deepEqual json, shouldHave

              done 9
