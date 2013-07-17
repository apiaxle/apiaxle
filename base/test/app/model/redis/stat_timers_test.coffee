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

  _logManyTimes: ( times, cb ) ->
    all = []

    for time in times
      do( time ) =>
        all.push ( cb ) =>
          multi = @model.multi()
          @model.logTiming multi, "/v1/api/:api", time, ( err ) =>
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
    @_logManyTimes [ 1, 2, 3, 4 ], ( err, values ) =>
      @ok not err

      done 1