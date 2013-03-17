async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"
{ Stats }   = require "../../../../app/model/redis/stats"

class exports.StatsTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "stats"
    done()

  "test #recordHit": ( done ) ->
    @model.recordHit ["key","1234", "200"],  ( err, result ) =>
      @isNull err
      @equal result[0], 1
      done()

  "test #get": ( done ) ->
    now = (new Date()).getTime()
    now_seconds = Math.floor(now/1000)

    all = []
    all.push (cb) =>
      clock = @getClock()
      @model.recordHit ["key","1234", "200"], cb
    all.push (cb) =>
      clock = @getClock now + 2000
      @model.recordHit ["key","1234", "200"], cb

    async.series all, (err, result) =>
      @isNull err
      from = now

      @model.get ["key", "1234", "200"], "seconds", from, null, (err, result) =>
        @isNull err
        @equal result[now_seconds],1
        @equal result[now_seconds+1],0
        done(4)

  # Ensure we get a senible response when rolling across minute boundary
  "test #get rolling period": (done) ->
    clock = @getClock()
    now  = (new Date()).getTime()
    next = now + (3600+1)*1000
    now_seconds = Math.floor(now/1000)
    next_seconds = Math.floor(next/1000)

    all = []
    all.push (cb) =>
      clock = @getClock now
      @model.recordHit ["key","1234", "200"], cb
    all.push (cb) =>
      # Jump into the next hour
      clock = @getClock next
      @model.recordHit ["key","1234", "200"], cb

    async.series all, (err, result) =>
      # bring the clock back
      clock = @getClock(now)
      @isNull err
      from = now - 3000

      @model.get ["key", "1234", "200"], "seconds", from, next+1000, (err, result) =>
        @isNull err
        @equal result[now_seconds],1
        @equal result[next_seconds],1
        done(4)
