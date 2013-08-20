# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
async = require "async"

{ RedisMulti } = require "../../../../app/model/redis"
{ FakeAppTest } = require "../../../apiaxle_base"

class exports.CountersTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup api": ( done ) ->
    fixtures =
      api:
        facebook:
          endPoint: "example.com"

    @fixtures.create fixtures, done

  "test initialisation": ( done ) ->
    @ok @app
    @ok @model = @app.model "capturepaths"

    done 2

  "test logging some stats": ( done ) ->
    stub = @getStub RedisMulti::, "expireat", ->

    # fix the clock
    clock = @getClock 1376854000000
    now = Math.floor( Date.now() / 1000 )

    matches = [ "/one/:two", "/one/:two/three" ]

    all = []

    # hit for facebook
    all.push ( cb ) => @model.log [ "facebook" ], matches, 100, cb

    # see if we can fetch the timing results
    all.push ( cb ) =>
      @model.getTimers [ "facebook" ], matches, "minute", now - 60, now, ( err, results ) =>
        @ok not null

        @deepEqual results,
          "/one/:two":
            1376853960: [ 100, 100, 100 ]

          "/one/:two/three":
            1376853960: [ 100, 100, 100 ]

        return cb null

    # see if we can fetch the counter results
    all.push ( cb ) =>
      @model.getCounters [ "facebook" ], matches, "minute", now - 60, now, ( err, results ) =>
        @ok not null

        @deepEqual results,
          "/one/:two":
            1376853960: 1

          "/one/:two/three":
            1376853960: 1

        return cb null

    async.series all, ( err ) =>
      @ok not err

      done 3
