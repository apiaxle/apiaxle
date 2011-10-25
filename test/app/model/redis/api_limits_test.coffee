async = require "async"

{ QpsExceededError, QpdExceededError } = require "../../../../lib/error"
{ GatekeeperTest } = require "../../../gatekeeper"

class exports.QpdTest extends GatekeeperTest
  @empty_db_on_setup = true

  "test initialisation": ( done ) ->
    @ok @gatekeeper
    @ok model = @gatekeeper.model "apiLimits"

    @equal model.ns, "gk:test:apilimits:"

    done 3

  "test #withinQpd with two qpd": ( done ) ->
    model = @gatekeeper.model "apiLimits"

    model.withinQpd "fred", "1234", 20, ( err, result ) =>
      @isNull err
      @equal result, 20

      # check the key was set
      model.get model.qpdKey( "fred", "1234" ), ( err, value ) =>
        @isNull err
        @equal value, 20

        # this makes the bold assumption that the tests are quick
        # enough to get here before ttl expires
        model.ttl model.qpdKey( "fred", "1234" ), ( err, ttl ) =>
          @isNull err
          @ok ttl > 0

          done 6

  "test #withinQpd with zero qpd": ( done ) ->
    model = @gatekeeper.model "apiLimits"

    # set the initial qpd
    model.withinQpd "fred", "1234", 2, ( err, result ) =>
      @isNull err
      @equal result, 2

      # then zero the qpd to check we get an error
      model.set model.qpdKey( "fred", "1234" ), 0, ( err, result ) =>
        @isNull err

        # this time should error
        model.withinQpd "fred", "1234", 2, ( err, result ) =>
          @ok err
          @isUndefined result

          @ok err instanceof QpdExceededError

          @equal err.constructor.status, 429
          @equal err.message, "Queries per day exceeded: 2 allowed."

          done 8

class exports.QpsTest extends GatekeeperTest
  @empty_db_on_setup = true

  "test initialisation": ( done ) ->
    @ok @gatekeeper
    @ok model = @gatekeeper.model "apiLimits"

    @equal model.ns, "gk:test:apilimits:"

    done 3

  "test #withinQps with two qps": ( done ) ->
    model = @gatekeeper.model "apiLimits"

    model.withinQps "bob", "1234", 2, ( err, result ) =>
      @isNull err
      @equal result, 2

      # check the key was set
      model.get model.qpsKey( "bob", "1234" ), ( err, value ) =>
        @isNull err
        @equal value, 2

        # this makes the bold assumption that the tests are quick
        # enough to get here before ttl expires
        model.ttl model.qpsKey( "bob", "1234" ), ( err, ttl ) =>
          @isNull err
          @ok ttl > 0

          done 6

  "test #withinQps with zero qps": ( done ) ->
    model = @gatekeeper.model "apiLimits"

    # set the initial qps
    model.withinQps "bob", "1234", 2, ( err, result ) =>
      @isNull err
      @equal result, 2

      # then zero the qps to check we get an error
      model.set model.qpsKey( "bob", "1234" ), 0, ( err, result ) =>
        @isNull err

        # this time should error
        model.withinQps "bob", "1234", 2, ( err, result ) =>
          @ok err
          @isUndefined result

          @ok err instanceof QpsExceededError

          @equal err.constructor.status, 429
          @equal err.message, "Queries per second exceeded: 2 allowed."

          done 8
