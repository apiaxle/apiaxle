async = require "async"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.KeysControllerTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "test list keys without resolution": ( done ) ->
    # create 11 keys
    fixtures = []
    model = @app.model "keyfactory"

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          model.create "key_#{i}", {}, cb

    async.series fixtures, ( err, newKeys ) =>
      @ok not err

      @GET path: "/v1/keys?from=1&to=12", ( err, response ) =>
        @ok not err

        response.parseJson ( err, json ) =>
          @ok not err
          @ok json
          @equal json.results.length, 10

          done 5

  "test list keys with resolution": ( done ) ->
    # create 11 keys
    fixtures = []

    model = @app.model "keyfactory"

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          options =
            qps: 20
            qpd: 30

          model.create "key_#{i}", options, cb

    async.parallel fixtures, ( err, newKeys ) =>
      @ok not err

      @GET path: "/v1/keys?from=0&to=12&resolve=true", ( err, response ) =>
        @ok not err

        response.parseJson ( err, json ) =>
          @ok not err
          @ok json

          for i in [ 0..9 ]
            name = "key_#{i}"

            @ok json.results[ name ]
            @equal json.results[ name ].qpd, 30
            @equal json.results[ name ].qps, 20

          done 34
