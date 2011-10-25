async = require "async"

{ GatekeeperTest } = require "../../../gatekeeper"

class exports.UserTest extends GatekeeperTest
  @empty_db_on_setup = true

  "test initialisation happened": ( done ) ->
    @ok @gatekeeper
    @ok model = @gatekeeper.model "user"

    @equal model.ns, "gk:test:user:"

    done 3

  "test #apiHit": ( done ) ->
    model = @gatekeeper.model( "user" )

    hits = [ ]

    for i in [ 1..100 ]
      hits.push ( cb ) ->
        model.apiHit "1234", cb

    async.parallel hits, ( err, results ) =>
      @isUndefined err
      @equal results.length, 100

      model.callsToday "1234", ( err, value ) =>
        @isNull err
        @equal 100, value

        done 4
