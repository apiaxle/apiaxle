async = require "async"

{ GatekeeperTest } = require "../../../gatekeeper"

class exports.CountersTest extends GatekeeperTest
  @empty_db_on_setup = true

  "test initialisation": ( done ) ->
    @ok @gatekeeper
    @ok model = @gatekeeper.model "counters"

    @equal model.ns, "gk:test:ct"

    done 3

  "test #apiHit": ( done ) ->
    model = @gatekeeper.model "counters"

    hits = for i in [ 1..100 ]
      ( cb ) -> model.apiHit "1234", cb

    async.parallel hits, ( err, results ) =>
      @isUndefined err
      @equal results.length, 100

      model.callsToday "1234", ( err, value ) =>
        @isNull err
        @equal 100, value

        done 4
