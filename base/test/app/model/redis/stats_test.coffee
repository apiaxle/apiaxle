async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"

class exports.StatsTest extends FakeAppTest
  @empty_db_on_setup = true

  "test initialisation": ( done ) ->
    @ok @app
    @ok @model = @app.model "stats"
    @equal @model.ns, "gk:test:stats"

    done 3

  "test #record API hit": ( done ) ->
    clock = @getClock 1323892867000

    @model.hit "facebook", "1234", 200, ( err, result ) =>
      @isNull err
      @equal result[0], 1
      @equal result[1], 1

      @model.hit "facebook", "1234", 200, ( err, result ) =>
        @isNull err
        @equal result[0], 2
        @equal result[1], 2

        done 6
