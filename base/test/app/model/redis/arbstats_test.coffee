_ = require "lodash"
async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"
{ Stats }   = require "../../../../app/model/redis/stats"

class exports.ArbStatsTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "arbstats"

    done()

  "test #roundedTimestamp": ( done ) ->
    @equal @model.roundedTimestamp( 60, 1000 ), 960
    @equal @model.roundedTimestamp( 60, 1021 ), 1020

    @equal @model.roundedTimestamp( 60, 120 ), 120
    @equal @model.roundedTimestamp( 1, 60 ), 60

    done 4

  "test a simple counter increment": ( done ) ->
    clock = @getClock 1357002210000 # Tue, 01 Jan 2013 01:03:30 GMT
    multi = @model.multi()

    # seconds window changes at 1357005600

    all = []
    all.push ( cb ) =>
      @model.logCounter multi, "http.get.200", ( err, values ) =>
        @ok not err

        # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
        # 1357002210 => Tue, 01 Jan 2013 01:03:30 GMT
        @deepEqual values.second, [ 1356998400, 1357002210 ]

        # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
        # 1357002180 => Tue, 01 Jan 2013 01:03:00 GMT
        @deepEqual values.minute, [ 1356998400, 1357002180 ]

        cb()

    # 3 seconds later
    all.push ( cb ) =>
      clock.addSeconds 3
      # now we're at 1357002213 => Tue, 01 Jan 2013 01:03:33 GMT

      @model.logCounter multi, "http.get.200", ( err, values ) =>
        @ok not err

        # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
        # 1357002213 => Tue, 01 Jan 2013 01:03:33 GMT
        @deepEqual values.second, [ 1356998400, 1357002213 ]

        # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
        # 1357002180 => Tue, 01 Jan 2013 01:03:00 GMT
        @deepEqual values.minute, [ 1356998400, 1357002180 ]

        cb()

    # 3 minutes later
    all.push ( cb ) =>
      clock.addMinutes 3
      # now we're at 1357002393 => Tue, 01 Jan 2013 01:06:33 GMT

      @model.logCounter multi, "http.get.200", ( err, values ) =>
        @ok not err

        # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
        # 1357002213 => Tue, 01 Jan 2013 01:06:33 GMT
        @deepEqual values.second, [ 1356998400, 1357002393 ]

        # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
        # 1357002360 => Tue, 01 Jan 2013 01:06:00 GMT
        @deepEqual values.minute, [ 1356998400, 1357002360 ]

        cb()

    async.series all, ( err ) =>
      @ok not err

      done 2
