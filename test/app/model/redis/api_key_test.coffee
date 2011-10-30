async = require "async"

{ ValidationError } = require "../../../../lib/error"
{ GatekeeperTest } = require "../../../gatekeeper"

class exports.ApiKeyTest extends GatekeeperTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @gatekeeper.model "apiKey"

    done()

  "test initialisation": ( done ) ->
    @ok @gatekeeper
    @ok @model

    @equal @model.ns, "gk:test:key"

    done 3

  "test #create with bad structure": ( done ) ->
    createObj =
      qpd: "text"

    @model.create "987654321", createObj, ( err ) =>
      @ok err

      done 1

  "test #create with non-existent api": ( done ) ->
    createObj =
      qps: 1
      qpd: 3
      forApi: "twitter"

    @model.create "987654321", createObj, ( err ) =>
      @ok err
      @equal err.message, "API '987654321' doesn't exist."

      done 2

  "test #create with an existant api": ( done ) ->
    createObj =
      qps: 1
      qpd: 3
      forApi: "twitter"

    @gatekeeper.model( "api" ).create "twitter", endpoint: "api.twitter.com", ( err, newApi ) =>
      @model.create "987654321", createObj, ( err ) =>
        @isNull err

        done 1
