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
        res.parseJson ( json ) =>
          @deepEqual json.results, _.pluck( keyrings[2..4], "id" )

          done 2

  "test GET keys for a valid keyring": ( done ) ->
    @fixtures.createApi "twitter", ( err ) =>
      @fixtures.createKeyring "blah", ( err, keyring ) =>
        new_keys = []

        # create a bunch of keys
        for i in [ 1..15 ]
          new_keys.push ( cb ) =>
            @fixtures.createKey ( err, key ) =>
              keyring.addKey key.id, cb

        async.series new_keys, ( err, keys ) =>
          @isNull err

          @GET path: "/v1/keyring/blah/keys?from=0&to=9", ( err, res ) =>
            @isNull err
            res.parseJson ( json ) =>
              @equal json.results.length, 10
              @deepEqual json.results, _.pluck( keys[ 0..9 ], "id")

              done 4

  "test GET a non-existant keyring": ( done ) ->
    # now try and get it
    @GET path: "/v1/keyring/1234", ( err, res ) =>
      @isNull err
      @equal res.statusCode, 404

      res.parseJson ( json ) =>
        @ok json.results.error
        @equal json.results.error.type, "NotFoundError"

        done 4

  "test GET a non-existant keyring": ( done ) ->
    # now try and get it
    @GET path: "/v1/keyring/1234", ( err, res ) =>
      @isNull err
      @equal res.statusCode, 404

      res.parseJson ( json ) =>
        @ok json.results.error
        @equal json.results.error.type, "NotFoundError"

        done 4
