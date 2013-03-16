async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"
{ Stats }   = require "../../../../app/model/redis/stats"

class exports.StatsTest extends FakeAppTest
  # @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "stats"
    done()

  "test #recordHit": ( done ) ->
    clock = @getClock 1323892867000

    @model.recordHit ["stutest","key", "200"],  ( err, result ) =>
      @isNull err
      @equal result[0], 1
      done()
