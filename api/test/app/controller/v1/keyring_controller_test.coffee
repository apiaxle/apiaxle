_     = require "underscore"
async = require "async"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.KeyringControllerTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "test GET a valid keyring": ( done ) ->
    # now try and get it
    @GET path: "/v1/keyring/1234", ( err, res ) =>
      @isNull err
      res.parseJson ( json ) =>
        @ok 1

        done 2

  "test GET a list of keyrings": ( done ) ->
    all_keyrings = []

    for i in [ 1..15 ]
      all_keyrings.push @fixtures.createKeyring

    async.series all_keyrings, ( err, keyrings ) =>
      @isNull err

      @GET path: "/v1/keyrings?from=2&to=4", ( err, res ) =>
        res.parseJson ( err, json ) =>
          @isNull err
          @deepEqual json.results, _.pluck( keyrings[2..4], "id" )

          done 3

  "test GET keys for a valid keyring": ( done ) ->
    fixtures =
      api:
        twitter: {}
      key:
        1: {}
        2: {}
        3: {}
        4: {}
        5: {}
      keyring:
        blah: {}

    @fixtures.create fixtures, ( err ) =>
      @isNull err

      @GET path: "/v1/keyring/blah/keys?from=0&to=9", ( err, res ) =>
        @isNull err
        res.parseJson ( err, json ) =>
          @isNull err
          @equal json.results.length, 5

          done 4

  "test GET a non-existant keyring": ( done ) ->
    # now try and get it
    @GET path: "/v1/keyring/1234", ( err, res ) =>
      @isNull err
      @equal res.statusCode, 404

      res.parseJson ( err, json ) =>
        @isNull err
        @ok json.results.error
        @equal json.results.error.type, "KeyringNotFoundError"

        done 5

  "test PUTing a valid key to an invalid keyring": ( done ) ->
    fixture =
      api:
        twitter: {}
      key:
        9876: {}

    @fixtures.create fixture, ( err ) =>
      @isNull err

      @PUT path: "/v1/keyring/ring1/linkkey/1234", ( err, res ) =>
        @isNull err

        res.parseJson ( err, json ) =>
          @isNull err
          @ok err = json.results.error
          @equal err.type, "KeyringNotFoundError"
          @equal err.message, "Keyring 'ring1' not found."

          done 6

  "test PUTing an invalid key to a valid keyring": ( done ) ->
    fixture =
      keyring:
        ring1: {}

    @fixtures.create fixture, ( err ) =>
      @isNull err

      @PUT path: "/v1/keyring/ring1/linkkey/1234", ( err, res ) =>
        @isNull err

        res.parseJson ( err, json ) =>
          @isNull err
          @ok err = json.results.error
          @equal err.type, "KeyNotFoundError"
          @equal err.message, "Key '1234' not found."

          done 6

  "test PUTing a valid key to a valid keyring": ( done ) ->
    fixture =
      api:
        twitter: {}
      key:
        1234: {}
        5678: {}
      keyring:
        ring1: {}
        ring2: {}

    @fixtures.create fixture, ( err ) =>
      @isNull err

      model = @app.model( "keyringFactory" )
      model.find "ring1", ( err, keyring ) =>
        @isNull err
        @ok keyring
        @equal keyring.id, "ring1"

        add_key_functions = []
        add_key_functions.push ( cb ) =>
          @PUT path: "/v1/keyring/ring1/linkkey/1234", ( err, res ) =>
            @isNull err
            res.parseJson ( err, json ) =>
              @isNull err
              @equal json.results.qps, 2

              # get all of the keys, check there's just one
              keyring.getKeys 0, 100, ( err, keys ) =>
                @deepEqual keys, [ "1234" ]

                cb()

        add_key_functions.push ( cb ) =>
          @PUT path: "/v1/keyring/ring1/linkkey/5678", ( err, res ) =>
            @isNull err
            res.parseJson ( err, json ) =>
              @isNull err
              @equal json.results.qps, 2

              # get all of the keys, check there's just one
              keyring.getKeys 0, 100, ( err, keys ) =>
                @deepEqual keys, [ "5678", "1234" ]

                cb()

        async.series add_key_functions, ( err ) =>
          @isNull err

          done 13
