async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"
{ Stats }   = require "../../../../app/model/redis/stats"

class exports.StatsTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "stats"
    done()

  "test #recordHit": ( done ) ->
    @model.recordHit ["key","1234", "cached", "200"],  ( err, result ) =>
      @isNull err
      @equal result[0], 1
      done()

  "test #get": ( done ) ->
    now = Date.now()
    clock = @getClock now

    now_seconds = Math.floor( now / 1000 )

    all = []
    all.push ( cb ) =>
      @model.recordHit ["key","1234", "cached", "200"], cb

    all.push ( cb ) =>
      clock.addSeconds 2
      @model.recordHit ["key","1234", "cached", "200"], cb

    all.push ( cb ) =>
      clock.addMinutes 2
      @model.recordHit ["key","1234", "cached", "200"], cb

    async.series all, ( err, result ) =>
      @isNull err
      from = now_seconds - 3

      @model.get ["key", "1234", "cached", "200"], "seconds", from, null, ( err, result ) =>
        @isNull err
        @equal result[now_seconds], 1

        # there shouldn't be a value for this as we made no hit
        @isUndefined result[now_seconds + 1]

        @equal result[now_seconds + 120 + 2 ], 1
        @model.get ["key", "1234", "cached", "200"], "minutes", from, null, ( err, result ) =>
          time = Math.floor( now_seconds/ 60 ) * 60
          @equal result[time + 120], 1

          done 6

  # Ensure we get a senible response when rolling across minute boundary
  "test #get rolling period": ( done ) ->
    now  = Date.now()
    clock = @getClock now

    next = now + ( 3600 + 1 ) * 1000
    now_seconds = Math.floor( now/1000 )
    next_seconds = Math.floor( next/1000 )

    all = []
    all.push ( cb ) =>
      clock.set now
      @model.recordHit ["key","1234", "200"], cb

    # jump into the next hour
    all.push ( cb ) =>
      clock.set next
      @model.recordHit ["key","1234", "200"], cb

    async.series all, ( err, result ) =>
      @isNull err
      from = now_seconds - 3
      to   = next_seconds + 1

      @model.get ["key", "1234", "200"], "seconds", from, to, ( err, result ) =>
        @isNull err
        @equal result[now_seconds],1
        @equal result[next_seconds],1
        done 4

  "test #Invalid time range": ( done ) ->
    from  = Date.now()
    all = []

    all.push ( cb ) =>
      @model.get ["key", "1234", "cached", "200"], "seconds", from, from - 1000, cb

    all.push ( cb ) =>
      @model.get ["key", "1234", "cached", "200"], "seconds", from - ( 1000 * 3720 ), from + 1000, cb

    async.series all, ( err, result ) =>
      @isNotNull err
      done 1
