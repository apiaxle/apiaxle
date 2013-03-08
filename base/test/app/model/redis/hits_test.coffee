async = require "async"

{ FakeAppTest } = require "../../../apiaxle-base"

class exports.StatsTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "hits"

    done()

  "test initialisation": ( done ) ->
    @ok @model
    @equal @model.ns, "gk:test:hits"

    done 2

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

  "test #get current hit count for a key ( > 0)": ( done ) ->
    clock = @getClock 1323892867000
    all = []
    all.push ( cb ) => @model.hit "facebook", 12345, 200, cb
    all.push ( cb ) => @model.hit "facebook", 12345, 200, cb

    async.series all, ( err, results ) =>
      @isNull err

      @model.getRealTime "key", 12345, ( err, hits ) =>
        @isNull err
        @equal hits, 2

        done 3

  "test #get current hit count for a key without hits": ( done ) ->
    clock = @getClock 1323892867000
    # Hit some other key
    all = []
    all.push ( cb ) => @model.hit "facebook", 12345, 200, cb
    all.push ( cb ) => @model.hit "facebook", 12345, 200, cb

    async.series all, ( err, results ) =>
      @isNull err

      @model.getRealTime "key", 1234, ( err, hits ) =>
        @isNull err
        @equal hits, 0

        done 3

  "test #get minute of hit data": ( done ) ->
    clock = @getClock 1323892867000
    all = []

    all.push ( cb ) => @model.hit "facebook", 12345, 200, cb
    all.push ( cb ) => @model.hit "facebook", 12345, 200, cb

    # Bump the clock 1 sec
    all.push ( cb ) =>
      clock.addSeconds 1
      cb()

    all.push ( cb ) => @model.hit "facebook", 12345, 200, cb
    all.push ( cb ) => @model.hit "facebook", 12345, 200, cb
    all.push ( cb ) => @model.hit "facebook", 12345, 200, cb

    async.series all, ( err, results ) =>
      @isNull err

      @model.getCurrentMinute "api", "facebook", ( err, result ) =>
        @isNull err
        @equal result["1323892867"], 2
        @equal result["1323892868"], 3

        done 4
