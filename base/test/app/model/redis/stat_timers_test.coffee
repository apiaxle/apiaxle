_ = require "lodash"
async = require "async"

{ RedisMulti } = require "../../../../app/model/redis"
{ FakeAppTest } = require "../../../apiaxle_base"

class exports.TimerStatsTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "stattimers"

    done()

  _avg: ( arr ) ->
    sum = 0
    sum += i for i in arr
    return ( sum / arr.length )

  _logManyTimes: ( name, times, cb ) ->
    all = []

    for time in times
      do( time ) =>
        all.push ( cb ) =>
          multi = @model.multi()
          @model.logTiming multi, [ "NS" ], name, time, ( err ) =>
            return cb err if err
            multi.exec cb

    async.series all, cb

  "test #_getNewValues": ( done ) ->
    [ min, max, avg ] = @model._getNewValues 2, 1, 4, 2, 20
    @equal min, 1
    @equal max, 4
    @equal avg, 2

    [ min, max, avg ] = @model._getNewValues 1000, 1, 4, 2, 20
    @equal min, 1
    @equal max, 1000

    [ min, max, avg ] = @model._getNewValues 2, 3, 4, 2, 20
    @equal min, 2
    @equal max, 4

    done 7

  "test a simple hit": ( done ) ->
    clock = @getClock 1357002210000 # Tue, 01 Jan 2013 01:03:30 GMT

    # stub expireat so that we don't run out of time on the redis-side
    # of things. Record the time so we can query it.
    expireables = {}
    stub = @getStub RedisMulti::, "expireat", ( key, ts ) =>
      expireables[key] = ts

    @_logManyTimes "bob", [ 1, 2, 3, 4 ], ( err, values ) =>
      @ok not err

      from = 1357002000 # Tue, 01 Jan 2013 01:00:00 GMT
      to = from + 120

      @model.getValues [ "NS" ], [ "bob" ], "hour", from, to, ( err, results ) =>
        @ok not err

        @deepEqual results,
          bob:
            "1357002000": [ 1, 4, 2.5 ]

        expiry_times = _( expireables ).values()
                                       .map( ( v ) => v - 1357002210 )
                                       .valueOf()

        @deepEqual expiry_times, [ 7200, 86370, 604590, 62895390 ]

        done 4
