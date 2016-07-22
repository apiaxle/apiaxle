# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
_     = require "lodash"
async = require "async"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.KeyringControllerTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "test POST a valid keyring": ( done ) ->
    # now try and get it
    options =
      path: "/v1/keyring/helloworld"
      headers:
        "Content-Type": "application/json"
      data: "{}"

    @POST options, ( err, res ) =>
      @ok not err

      res.parseJsonSuccess ( err, meta, results ) =>
        @ok not err
        @ok results.createdAt

        done 3

  "test DELETE a valid keyring": ( done ) ->
    fixtures =
      keyring:
        container: {}
        container1: {}
        container2: {}

    # now try and get it
    @fixtures.create fixtures, ( err ) =>
      @ok not err

      @GET path: "/v1/keyrings", ( err, res ) =>
        @ok not err

        res.parseJsonSuccess ( err, meta, results ) =>
          @equal results.length, 3

          @DELETE path: "/v1/keyring/container1", ( err ) =>
            @ok not err

            @GET path: "/v1/keyrings", ( err, res ) =>
              @ok not err

              res.parseJsonSuccess ( err, meta, results ) =>
                @equal results.length, 2
                @deepEqual results, [ "container", "container2" ]

                done 7

  "test GET a valid keyring": ( done ) ->
    # now try and get it
    @fixtures.createKeyring "1234", {}, ( err, dbKr ) =>
      @ok not err
      @ok dbKr

      @GET path: "/v1/keyring/1234", ( err, res ) =>
        @ok not err

        res.parseJsonSuccess ( err, meta, results ) =>
          @ok not err
          @equal results.createdAt, dbKr.data.createdAt

          done 5

  "test GET a list of keyrings": ( done ) ->
    all_keyrings = []

    for i in [ 1..15 ]
      do( i ) =>
        all_keyrings.push ( cb ) =>
          @fixtures.createKeyring "kr#{ i }", {}, cb

    async.series all_keyrings, ( err, keyrings ) =>
      @ok not err

      @GET path: "/v1/keyrings?from=2&to=4", ( err, res ) =>
        res.parseJson ( err, json ) =>
          @ok not err
          @deepEqual json.results, _.pluck( keyrings[2..4], "id" )

          done 3

  "test GET keys for a valid keyring": ( done ) ->
    fixtures =
      api:
        twitter:
          endPoint: "example.com"
      key:
        1: {}
        2: {}
        3: {}
        4: {}
        5: {}
      keyring:
        blah: {}

    @fixtures.create fixtures, ( err ) =>
      @ok not err

      @GET path: "/v1/keyring/blah/keys?from=0&to=9", ( err, res ) =>
        @ok not err
        res.parseJson ( err, json ) =>
          @ok not err
          @equal json.results.length, 0

          @PUT path: "/v1/keyring/blah/linkkey/1", ( err, res ) =>
            @ok not err

            @PUT path: "/v1/keyring/blah/linkkey/4", ( err, res ) =>
              @ok not err

              @GET path: "/v1/keyring/blah/keys?from=0&to=9", ( err, res ) =>
                @ok not err
                res.parseJsonSuccess ( err, meta, results ) =>
                  @ok not err
                  @deepEqual results, [ "4", "1" ]

                  done 9

  "test GET a non-existant keyring": ( done ) ->
    # now try and get it
    @GET path: "/v1/keyring/1234", ( err, res ) =>
      @ok not err
      @equal res.statusCode, 404

      res.parseJson ( err, json ) =>
        @ok not err
        @ok json.results.error
        @equal json.results.error.type, "KeyringNotFoundError"

        done 5

  "test PUTing a valid key to an invalid keyring": ( done ) ->
    fixture =
      api:
        twitter:
          endPoint: "example.com"
      key:
        9876: {}

    @fixtures.create fixture, ( err ) =>
      @ok not err

      @PUT path: "/v1/keyring/ring1/linkkey/1234", ( err, res ) =>
        @ok not err

        res.parseJson ( err, json ) =>
          @ok not err
          @ok err = json.results.error
          @equal err.type, "KeyringNotFoundError"
          @equal err.message, "Keyring 'ring1' not found."

          done 6

  "test PUTing an invalid key to a valid keyring": ( done ) ->
    fixture =
      keyring:
        ring1: {}

    @fixtures.create fixture, ( err ) =>
      @ok not err

      @PUT path: "/v1/keyring/ring1/linkkey/1234", ( err, res ) =>
        @ok not err

        res.parseJson ( err, json ) =>
          @ok not err
          @ok err = json.results.error
          @equal err.type, "KeyNotFoundError"
          @equal err.message, "Key '1234' not found."

          done 6

  "test PUTing a valid key to a valid keyring": ( done ) ->
    fixture =
      api:
        twitter:
          endPoint: "example.com"
      key:
        1234: {}
        5678: {}
      keyring:
        ring1: {}
        ring2: {}

    @fixtures.create fixture, ( err ) =>
      @ok not err

      model = @app.model( "keyringfactory" )
      model.find [ "ring1" ], ( err, results ) =>
        @ok not err
        @ok results.ring1
        @equal results.ring1.id, "ring1"

        add_key_functions = []
        add_key_functions.push ( cb ) =>
          @PUT path: "/v1/keyring/ring1/linkkey/1234", ( err, res ) =>
            @ok not err
            res.parseJson ( err, json ) =>
              @ok not err
              @equal json.results.disabled, false

              # get all of the keys, check there's just one
              results.ring1.getKeys 0, 100, ( err, keys ) =>
                @deepEqual keys, [ "1234" ]

                cb()

        add_key_functions.push ( cb ) =>
          @PUT path: "/v1/keyring/ring1/linkkey/5678", ( err, res ) =>
            @ok not err
            res.parseJson ( err, json ) =>
              @ok not err
              @equal json.results.disabled, false

              # get all of the keys, check there's just one
              results.ring1.getKeys 0, 100, ( err, keys ) =>
                @deepEqual keys, [ "5678", "1234" ]

                cb()

        async.series add_key_functions, ( err ) =>
          @ok not err

          done 13
