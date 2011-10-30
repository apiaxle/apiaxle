async = require "async"

{ ValidationError } = require "../../../../lib/error"
{ GatekeeperTest } = require "../../../gatekeeper"

class exports.ApiTest extends GatekeeperTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @gatekeeper.model "api"

    done()

  "test initialisation": ( done ) ->
    @ok @gatekeeper
    @ok @model

    @equal @model.ns, "gk:test:api"

    done 3

  "test #new with bad structure": ( done ) ->
    newObj =
      apiFormat: "text"

    @model.new "twitter", newObj, ( err ) =>
      @ok err

      done 1

  "test #new with good structure": ( done ) ->
    newObj =
      apiFormat: "xml"
      endpoint: "api.twitter.com"

    @model.new "twitter", newObj, ( err ) =>
      @isNull err

      @model.find "twitter", ( err, details ) =>
        @isNull err

        @equal details.apiFormat, "xml"
        @ok details.createdAt

        done 3
