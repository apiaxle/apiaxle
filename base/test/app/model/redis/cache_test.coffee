async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"

class exports.ApiTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @application.model "cache"

    done()

  "test initialisation": ( done ) ->
    @ok @application
    @ok @model

    @equal @model.ns, "gk:test:cache"

    done 3

