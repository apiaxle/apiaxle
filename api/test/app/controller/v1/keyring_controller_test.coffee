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

  "test GET keys for a valid keyring": ( done ) ->
    # now try and get it
    @GET path: "/v1/keyring/123/keys/0/10", ( err, res ) =>
      @isNull err
      res.parseJson ( json ) =>
        @ok 1

        done 2

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
