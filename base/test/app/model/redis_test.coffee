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

    writeCalled = false
    readCalled = false

    model.ee.once "write", ( command, key ) =>
      @equal command, "set"
      @equal key, "gk:test:ct:blah"

      writeCalled = true

    # we rely on the read happening last - if the tests get stuck it
    # might mean the write didn't fire.
    model.ee.once "read", ( command, key ) =>
      @equal command, "get"
      @equal key, "gk:test:ct:blah"

      readCalled = true

    model.set "blah", "hello", ( err ) =>
      model.get "blah", ( err, value ) =>
        @isNull err
        @equal value, "hello"

        # make sure we've called read and write before we go on.
        async.until(
          ( ) -> ( readCalled and writeCalled ),
          ( cb ) -> setTimeout cb, 100,
          ( ) -> done 7
        )


  "test multi key emitter": ( done ) ->
    @ok model = @application.model "counters"

    multi = model.multi()

    writeCalled = false
    readCalled = false

    multi.ee.once "write", ( command, key ) =>
      @equal command, "set"
      @equal key, "gk:test:ct:blah"

      writeCalled = true

    # we rely on the read happening last - if the tests get stuck it
    # might mean the write didn't fire.
    multi.ee.once "read", ( command, key ) =>
      @equal command, "get"
      @equal key, "gk:test:ct:blah"

      readCalled = true

    multi.set "blah", "hello"
    multi.get "blah"

    multi.exec ( err, results ) =>
      @isNull err
      @ok results

      # make sure we've called read and write before we go on.
      async.until(
        ( ) -> ( readCalled and writeCalled ),
        ( cb ) -> setTimeout cb, 100,
        ( ) -> done 7
      )
