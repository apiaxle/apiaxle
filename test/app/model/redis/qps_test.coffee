async = require "async"

{ GatekeeperTest } = require "../../../gatekeeper"

class exports.QpsTest extends GatekeeperTest
  @empty_db_on_setup = true

  "test initialisation": ( done ) ->
    @ok @gatekeeper
    @ok model = @gatekeeper.model "qps"

    @equal model.ns, "gk:test:qps:"

    done 3

  "test #apiHit": ( done ) ->
    model = @gatekeeper.model "qps"

    model.apiHit "bob", "1234", qps: 2, ( err, result ) =>
      @isNull err
      @equal result, 2

      done 2
