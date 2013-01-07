async = require "async"

{ ValidationError } = require "../../../../lib/error"
{ FakeAppTest } = require "../../../apiaxle_base"

class exports.KeyTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "keyFactory"

    done()

  "test initialisation": ( done ) ->
    @ok @app
    @ok @model

    @equal @model.ns, "gk:test:key"

    done 3

  "test #create with bad structure": ( done ) ->
    createObj =
      qpd: "text"

    @fixtures.createKey "987654321", createObj, ( err ) =>
      @ok err

      done 1

  "test #create with non-existent api": ( done ) ->
    createObj =
      qps: 1
      qpd: 3
      forApi: "twitter"

    @fixtures.createKey "987654321", createObj, ( err ) =>
      @ok err
      @equal err.message, "API 'twitter' doesn't exist."

      done 2

  "test #create with an existant api": ( done ) ->
    options =
      endPoint: "api.twitter.com"

    @app.model( "apiFactory" ).create "twitter", options, ( err, newApi ) =>
      @isNull err

      createObj =
        qps: 1
        qpd: 3
        forApi: "twitter"

      @fixtures.createKey "987654321", createObj, ( err ) =>
        @isNull err

        done 2
