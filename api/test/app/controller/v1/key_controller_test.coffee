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
        facebook:
          endPoint: "graph.facebook.com"

    @fixtures.create fixtures, ( err, [ @newApi ] ) ->
      done()

  "test GET a valid key": ( done ) ->
    @fixtures.createKey "1234", forApis: [ "twitter", "facebook" ], ( err, newKey ) =>
      @ok not err
      @ok newKey

      # now try and get it
      @GET path: "/v1/key/1234", ( err, res ) =>
        @ok not err

        res.parseJsonSuccess ( err, meta, results ) =>
          @ok not err

          @isNumber results.qps
          @isNumber results.qpd

          @deepEqual results.apis, [ "#{ @host_name }/v1/api/twitter",
                                     "#{ @host_name }/v1/api/facebook" ]

          done 6

  "test GET a non-existant key": ( done ) ->
    # now try and get it
    @GET path: "/v1/key/1234", ( err, res ) =>
      @ok not err
      @equal res.statusCode, 404

      res.parseJsonError ( err, meta, jsonerr ) =>
        @ok not err
        @equal jsonerr.type, "KeyNotFoundError"

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
      @ok not err

      res.parseJsonSuccess ( err, meta, results ) =>
        @ok not err

        @equal results.qps, 1
        @equal results.qpd, 100

        # check it went in
        @app.model( "keyfactory" ).find [ "1234" ], ( err, dbKey ) =>
          @ok not err

          @equal dbKey["1234"].data.qps, 1
          @equal dbKey["1234"].data.qpd, 100
          @ok dbKey["1234"].data.createdAt

          @app.model( "apifactory" ).find [ "twitter" ], ( err, dbKey ) =>
            @ok not err
            @ok dbKey.twitter

            dbKey.twitter.getKeys 0, 10, ( err, keys ) =>
              @equal keys.length, 1
              @equal keys[0], "1234"

              done 12

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
      @ok not err

      res.parseJsonError ( err, meta, jsonerr ) =>
        @ok not err

        @equal jsonerr.type, "ValidationError"
        @equal jsonerr.message, "The ‘qps’ property must be an ‘integer’. The type of the property is ‘string’"

        done 5

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
      @ok not err
      @ok origKey

      @PUT options, ( err, res ) =>
        @ok not err

        @equal res.statusCode, 200

        @app.model( "keyfactory" ).find [ "1234" ], ( err, results ) =>
          @equal results["1234"].data.qps, "30"
          @equal results["1234"].data.qpd, "1000"

          done 6

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
      @ok not err
      @ok origKey

      @PUT options, ( err, res ) =>
        @equal res.statusCode, 400

        res.parseJsonError ( err, meta, jsonerr ) =>
          @ok not err
          @equal jsonerr.type, "ValidationError"

          done 6

  "test DELETE with invalid KEY": ( done ) ->
    @DELETE path: "/v1/key/1234", ( err, res ) =>
      @equal res.statusCode, 404

      res.parseJsonError ( err, meta, jsonerr ) =>
        @ok not err
        @ok meta.status_code, 404

        @equal jsonerr.message, "Key '1234' not found."
        @equal jsonerr.type, "KeyNotFoundError"

        done 6

  "test DELETE with valid key": ( done ) ->
    @fixtures.createKey "1234", forApis: [ "twitter" ], ( err, origKey ) =>
      @ok not err
      @ok origKey

      @DELETE path: "/v1/key/1234", ( err, res ) =>
        @ok not err
        @equal res.statusCode, 200

        res.parseJsonSuccess ( err, meta, results ) =>
          @ok not err

          # just returns true
          @equal results, true
          @equal meta.status_code, 200

          # confirm it's out of the database
          @app.model( "keyfactory" ).find [ "1234" ], ( err, dbKey ) =>
            @ok not err
            @ok not dbKey["1234"]

            done 10

  "test get key range without resolution": ( done ) ->
    # create 11 keys
    fixtures = []

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          @fixtures.createKey "key_#{i}", forApis: [ "twitter" ], cb

    async.series fixtures, ( err, newKeys ) =>
      @ok not err

      @GET path: "/v1/keys?from=1&to=12", ( err, response ) =>
        @ok not err

        response.parseJsonSuccess ( err, meta, results ) =>
          @ok not err

          @equal results.length, 10

          done 5


  "test get key range with resolution": ( done ) ->
    # create 11 keys
    fixtures = []

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          @fixtures.createKey "key_#{i}", forApis: [ "twitter" ], qps: i, qpd: i, cb

    async.parallel fixtures, ( err, newKeys ) =>
      @ok not err

      @GET path: "/v1/keys?from=0&to=12&resolve=true", ( err, response ) =>
        @ok not err

        response.parseJsonSuccess ( err, meta, results ) =>
          @ok not err

          for i in [ 0..9 ]
            name = "key_#{i}"

            @ok results[ name ]
            @equal results[ name ].qpd, i
            @equal results[ name ].qps, i

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

  "test updating qpd mid-session resets users qpd": ( done ) ->
    fixtures =
      api:
        facebook:
          endPoint: "graph.facebook.com"
      key:
        phil:
          forApis: [ "facebook" ]
          qpd: 10
          qps: 300

    @fixtures.create fixtures, ( err, [ api, key ] ) =>
      @ok not err

      limitModel = @app.model "apilimits"

      # use up five of their hits, which should leave another five
      hits_to_run = []
      for i in [ 1..5 ]
        hits_to_run.push ( cb ) ->
          limitModel.apiHit "phil", 200, 10, cb

      async.series hits_to_run, ( err, results ) =>
        @ok not err

        limits_model = @app.model "apilimits"
        redis_key_name = limits_model.qpdKey "phil"
        limits_model.get redis_key_name, ( err, current_qpd ) =>
          @equal current_qpd, 5

          # now we try to update the qpd count so that this user gets
          # more hits
          options =
            path: "/v1/key/phil"
            headers:
              "Content-Type": "application/json"
            data: JSON.stringify
              qpd: 100

          @PUT options, ( err, res ) =>
            @ok not err

            res.parseJsonSuccess ( err, meta, results ) =>
              @ok not err

              @equal results.new.qpd, 100
              @equal results.old.qpd, 10

              # this should no longer error because we've updated the
              # qpd via the API
              limitModel.apiHit "phil", 200, 100, ( err, [ qpsLeft, qpdLeft ] ) =>
                @ok not err

                # 100 - 1 because we've hit the api
                # 99 - 5 because this user had already used 5 hits today
                @equal qpdLeft, 94

                done 9
