async = require "async"

{ GatekeeperTest } = require "../../../gatekeeper"

class exports.QpsTest extends GatekeeperTest
  @empty_db_on_setup = true

  "test initialisation": ( done ) ->
    @ok @gatekeeper
    @ok model = @gatekeeper.model "apiLimits"

    @equal model.ns, "gk:test:apilimits:"

    done 3

  "test #withinQps with two qps": ( done ) ->
    model = @gatekeeper.model "apiLimits"

    model.withinQps "bob", "1234", qps: 2, ( err, result ) =>
      @isNull err
      @equal result, 2

      # check the key was set
      model.get [ "bob", "1234" ], ( err, value ) =>
        @isNull err
        @equal value, 2

        # this makes the bold assumption that the tests are quick
        # enough to get here before ttl expires
        model.ttl [ "bob", "1234" ], ( err, ttl ) =>
          @isNull err
          @ok ttl > 0

          done 6

  "test #withinQps with zero qps": ( done ) ->
    model = @gatekeeper.model "apiLimits"

    # set the initial qps
    model.withinQps "bob", "1234", qps: 2, ( err, result ) =>
      @isNull err
      @equal result, 2

      # then zero the qps to check we get an error
      model.set [ "bob", "1234" ], 0, ( err, result ) =>
        @isNull err

        # this time should error
        model.withinQps "bob", "1234", qps: 2, ( err, result ) =>
          @ok err
          @isUndefined result

          done 5
