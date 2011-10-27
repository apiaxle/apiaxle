async = require "async"

{ GatekeeperTest } = require "../../gatekeeper"

class exports.RedisTest extends GatekeeperTest
  @empty_db_on_setup = true

  "test multi": ( done ) ->
    @ok model = @gatekeeper.model "counters"
    @ok multi = model.multi()

    multi.set [ "test" ], 1

    multi.exec ( err, results ) =>
      # check the key was written with the correct namespace
      model.get [ "test" ], ( err, value ) =>
        @isNull err
        @equal value, 1

        done 4
