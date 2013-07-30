_ = require "lodash"
async = require "async"

{ RedisMulti } = require "../../../../app/model/redis"
{ FakeAppTest } = require "../../../apiaxle_base"

class exports.ArbStatsTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "statcounters"

    done()

  "test #roundedTimestamp": ( done ) ->
    @equal @model.roundedTimestamp( 60, 1000 ), 960
    @equal @model.roundedTimestamp( 60, 1021 ), 1020

    @equal @model.roundedTimestamp( 60, 120 ), 120
    @equal @model.roundedTimestamp( 1, 60 ), 60

    done 4

  "test #getKeyValueTimestamps": ( done ) ->
    clock = @getClock 1357002210000 # Tue, 01 Jan 2013 01:03:30 GMT
    multi = @model.multi()

    # pretty print array of timestamps (used for debugging so that we
    # can see human readable dates too)
    valuesToIso = ( values ) ->
      _.map values, ( ts ) ->
        {}=
          ts: ts
          human: ( new Date( ts * 1000 ) ).toISOString()

    all = []
    all.push ( cb ) =>
      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002210 => Tue, 01 Jan 2013 01:03:30 GMT
      vals = @model.getKeyValueTimestamps( "second" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357002210 ] )

      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002180 => Tue, 01 Jan 2013 01:03:00 GMT
      vals = @model.getKeyValueTimestamps( "minute" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357002180 ] )

      # 1356566400 => Thu, 27 Dec 2012 00:00:00 GMT
      # 1357002000 => Tue, 01 Jan 2013 01:00:00 GMT
      vals = @model.getKeyValueTimestamps( "hour" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356566400, 1357002000 ] )

      cb()

    # 3 seconds later
    all.push ( cb ) =>
      clock.addSeconds 3
      # now we're at 1357002213 => Tue, 01 Jan 2013 01:03:33 GMT

      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002213 => Tue, 01 Jan 2013 01:03:33 GMT
      vals = @model.getKeyValueTimestamps( "second" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357002213 ] )

      # doesn't change this round
      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002180 => Tue, 01 Jan 2013 01:03:00 GMT
      vals = @model.getKeyValueTimestamps( "minute" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357002180 ] )

      # doesn't change this round
      # 1356566400 => Thu, 27 Dec 2012 00:00:00 GMT
      # 1357002000 => Tue, 01 Jan 2013 01:00:00 GMT
      vals = @model.getKeyValueTimestamps( "hour" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356566400, 1357002000 ] )

      cb()

    # 3 minutes later
    all.push ( cb ) =>
      clock.addMinutes 3
      # now we're at 1357002393 => Tue, 01 Jan 2013 01:06:33 GMT

      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002213 => Tue, 01 Jan 2013 01:06:33 GMT
      vals = @model.getKeyValueTimestamps( "second" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357002393 ] )

      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002360 => Tue, 01 Jan 2013 01:06:00 GMT
      vals = @model.getKeyValueTimestamps( "minute" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357002360 ] )

      # doesn't change this round
      # 1356566400 => Thu, 27 Dec 2012 00:00:00 GMT
      # 1357002000 => Tue, 01 Jan 2013 01:00:00 GMT
      vals = @model.getKeyValueTimestamps( "hour" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356566400, 1357002000 ] )

      cb()

    # 3 hours later
    all.push ( cb ) =>
      clock.addHours 3
      # now we're at 1357013193 => Tue, 01 Jan 2013 04:06:33 GMT

      # 1357012800 => Tue, 01 Jan 2013 04:00:00 GMT
      # 1357013193 => Tue, 01 Jan 2013 04:06:33 GMT
      vals = @model.getKeyValueTimestamps( "second" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1357012800, 1357013193 ] )

      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002360 => Tue, 01 Jan 2013 04:06:00 GMT
      vals = @model.getKeyValueTimestamps( "minute" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357013160 ] )

      # 1356566400 => Thu, 27 Dec 2012 00:00:00 GMT
      # 1357012800 => Tue, 01 Jan 2013 04:00:00 GMT
      vals = @model.getKeyValueTimestamps( "hour" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356566400, 1357012800 ] )

      cb()

    # 3 days later
    all.push ( cb ) =>
      clock.addDays 3
      # now we're at 1357272393 => Fri, 04 Jan 2013 04:06:33 GMT

      # 1357272000 => Fri, 04 Jan 2013 04:00:00 GMT
      # 1357272393 => Fri, 04 Jan 2013 04:06:33 GMT
      vals = @model.getKeyValueTimestamps( "second" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1357272000, 1357272393 ] )

      # 1357257600 => Fri, 04 Jan 2013 00:00:00 GMT
      # 1357272360 => Fri, 04 Jan 2013 04:06:00 GMT
      vals = @model.getKeyValueTimestamps( "minute" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1357257600, 1357272360 ] )

      # 1357171200 => Thu, 03 Jan 2013 00:00:00 GMT
      # 1357272000 => Fri, 04 Jan 2013 04:00:00 GMT
      vals = @model.getKeyValueTimestamps( "hour" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1357171200, 1357272000 ] )

      cb()

    async.series all, ( err ) =>
      @ok not err

      done 16

  "test #_getValidTimeRange": ( done ) ->
    from = 1375197120
    to = from + 120
    @ok range = @model._getValidTimeRange "minute", from, to
    @equal range.length, 3
    @deepEqual range, ( i for i in [from .. to ] by 60 )

    from = 1357002210
    to = from + 20
    @ok range = @model._getValidTimeRange "second", from, to
    @equal range.length, 21
    @deepEqual range, ( i for i in [from .. to ] )

    from = 1357002180
    to = from + 119
    @ok range = @model._getValidTimeRange "minute", from, to
    @equal range.length, 2
    @deepEqual range, ( i for i in [from .. to ] by 60 )

    done 9

  "test a simple counter hit": ( done ) ->
    clock = @getClock 1357002210000 # Tue, 01 Jan 2013 01:03:30 GMT

    # stub expireat so that we don't run out of time on the redis-side
    # of things. Record the time so we can query it.
    expireables = {}
    stub = @getStub RedisMulti::, "expireat", ( key, ts ) =>
      expireables[key] = ts

    all = []

    # log a counter
    all.push ( cb ) =>
      multi = @model.multi()
      @model.logCounter multi, "bob", ( err ) =>
        @ok not err

        # should be called once for each granularity
        @equal stub.callCount, 4

        multi.exec cb

    # fetch all of the names
    all.push ( cb ) =>
      @model.getAllCounterNames ( err, names ) =>
        @ok not err
        @deepEqual names, [ "bob" ]

        cb()

    # log another counter in the same second
    all.push ( cb ) =>
      multi = @model.multi()
      @model.logCounter multi, "frank", ( err ) =>
        @ok not err

        # should be called once for each granularity
        @equal stub.callCount, 8

        multi.exec cb

    # fetch all of the names again
    all.push ( cb ) =>
      @model.getAllCounterNames ( err, names ) =>
        @ok not err
        @deepEqual names, [ "bob", "frank" ]

        cb()

    # bob once more but a couple of seconds later
    all.push ( cb ) =>
      # takes us to 1357002212
      clock.addSeconds 2

      multi = @model.multi()
      @model.logCounter multi, "bob", ( err ) =>
        @ok not err

        # should be called once for each granularity
        @equal stub.callCount, 12

        multi.exec cb

    # now get the counts for bob in the last minute
    all.push ( cb ) =>
      from = 1357002180
      to = from + 600

      @model.getCounterValues [ "bob" ], "minute", from, to, ( err, results ) =>
        @ok not err

        # only 2 in the last minute
        @deepEqual results,
          bob:
            1357002180: 2

        cb()

    # now get the counts for bob and frank in the last minute
    all.push ( cb ) =>
      from = 1357002180
      to = from + 600

      @model.getCounterValues [ "bob", "frank" ], "minute", from, to, ( err, results ) =>
        @ok not err

        # only 2 in the last minute
        @deepEqual results,
          frank:
            1357002180: 1
          bob:
            1357002180: 2

        # deepEqual uses '==' so need to check ints
        @equal results.frank[1357002180], 1

        cb()

    # now get the counts for bob and frank in the last few seconds
    all.push ( cb ) =>
      from = 1357002210
      to = 1357002219

      @model.getCounterValues [ "bob", "frank" ], "second", from, to, ( err, results ) =>
        @ok not err

        # only 2 in the last minute
        @deepEqual results,
          frank:
            1357002210: 1
          bob:
            1357002210: 1
            1357002212: 1

        cb()

    async.series all, ( err ) =>
      @ok not err

      expiry_times = _( expireables ).values()
                                     .map( ( v ) => v - 1357002210 )
                                     .valueOf()

      @deepEqual expiry_times, [
        3, 30, 3390, 82590,
        1, 30, 3390, 82590 ]

      done 19
