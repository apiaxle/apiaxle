async = require "async"

{ FakeAppTest } = require "../../apiaxle_base"

class exports.RedisTest extends FakeAppTest
  @empty_db_on_setup = true

  "test multi incr/decr": ( done ) ->
    @ok model = @application.model "counters"
    @ok multi = model.multi()

    model.set [ "test" ], 20, ( err, value ) =>
      @isNull err

      multi.decr [ "test" ]
      multi.incr [ "test" ]
      multi.incr [ "test" ]

      multi.exec ( err, results ) =>
        @isNull err
        @deepEqual results, [ 19, 20, 21 ]

        model.get [ "test" ], ( err, value ) =>
          @equal value, 21

          done 6

  "test multi set/get": ( done ) ->
    @ok model = @application.model "counters"
    @ok multi = model.multi()

    multi.set [ "test" ], 1

    multi.exec ( err, results ) =>
      # check the key was written with the correct namespace
      model.get [ "test" ], ( err, value ) =>
        @isNull err
        @equal value, 1

        done 4

  "test key emitter": ( done ) ->
    @ok model = @application.model "counters"

    model.ee.on "write", ( command, key ) =>
      @equal command, "set"
      @equal key, "gk:test:ct:blah"

    # we rely on the read happening last - if the tests get stuck it
    # might mean the write didn't fire.
    model.ee.on "read", ( command, key ) =>
      @equal command, "get"
      @equal key, "gk:test:ct:blah"

      done 7

    model.set "blah", "hello", ( err ) =>
      model.get "blah", ( err, value ) =>
        @isNull err
        @equal value, "hello"
