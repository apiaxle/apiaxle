_ = require "lodash"
async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"
{ Stats }   = require "../../../../app/model/redis/stats"

class exports.StatsTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "stats"
    done()

  "test #get": ( done ) ->
    now = Date.now()
    clock = @getClock now

    now_seconds = Math.floor( now / 1000 )

    multi = @model.multi()

    @model.recordHit multi, ["key","1234", "cached", "200"]

    clock.addSeconds 2
    @model.recordHit multi, ["key","1234", "cached", "200"]

    clock.addMinutes 2
    @model.recordHit multi, ["key","1234", "cached", "200"]

    multi.exec ( err, result ) =>
      @ok not err
      from = now_seconds - 3

      @model.get ["key", "1234", "cached", "200"], "seconds", from, null, ( err, result ) =>
        @ok not err

        # we can't mock redis so there's a possiblity that the second
        # we capture above doesn't match what the redis server thinks
        # is the time. Extract the timestamp from the first record.
        server_time = parseInt( _.keys( result )[0] )

        @equal result[server_time], 1

        # there shouldn't be a value for this as we made no hit
        @isUndefined result[server_time + 1]

        @equal result[server_time + 120 + 2 ], 1
        @model.get ["key", "1234", "cached", "200"], "minutes", from, null, ( err, result ) =>
          time = Math.floor( server_time / 60 ) * 60
          @equal result[time + 120], 1

          done 6

  # Ensure we get a senible response when rolling across minute boundary
  "test #get rolling period": ( done ) ->
    now  = Date.now()
    clock = @getClock now

    next = now + ( 3600 + 1 ) * 1000
    now_seconds = Math.floor( now/1000 )
    next_seconds = Math.floor( next/1000 )

    multi = @model.multi()

    clock.set now
    @model.recordHit multi, ["key","1234", "200"]

    # jump into the next hour
    clock.set next
    @model.recordHit multi, ["key","1234", "200"]

    multi.exec ( err ) =>
      @ok not err
      from = now_seconds - 3
      to   = next_seconds + 1

      @model.get ["key", "1234", "200"], "seconds", from, to, ( err, result ) =>
        @ok not err
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
