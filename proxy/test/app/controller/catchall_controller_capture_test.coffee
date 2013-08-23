# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
_ = require "lodash"
url    = require "url"
async  = require "async"
libxml = require "libxmljs"

{ ApiaxleTest } = require "../../apiaxle"
{ RedisMulti } = require "../../../../base/app/model/redis"

class exports.CaptureTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup api/key": ( done ) ->
    fixture =
      api:
        programmes:
          endPoint: "bbc.co.uk"
      key:
        phil:
          forApis: [ "programmes" ]
          qps: 100
          qpd: 100

    @captures = [
      "/brand/*/programme/*",
      "/programme/*"
    ]

    @fixtures.create fixture, ( err, [ api ] ) =>
      throw err if err

      # add some capture paths
      all = []
      for capture in @captures
        do( capture ) =>
          all.push ( cb ) -> api.addCapturePath capture, cb

      async.series all, done

  "test timings/counters are captured": ( done ) ->
    dnsStub = @stubDns { "programmes.api.localhost": "127.0.0.1" }
    stub = @stubCatchallSimpleGet 200, null,
      "Content-Type": "application/json"

    all = []

    # fix the clock and stop things expiring
    clock = @getClock 1376854000000
    now = Math.floor( Date.now() / 1000 )
    stub = @getStub RedisMulti::, "expireat", ->

    fetch_args = [ [ "api", "programmes" ], @captures, "hour", now - 2000, null ]

    # test that hitting root DOES log as a capture
    all.push ( cb ) =>
      requestOptions =
        path: "/programme/toystory?api_key=phil"
        host: "programmes.api.localhost"

      @GET requestOptions, cb

    model = @app.model "capturepaths"
    all.push ( cb ) =>
      # one set of timings
      model.getTimers fetch_args..., ( err, timings ) =>
        @ok not null
        @deepEqual timings,
          "/brand/*/programme/*": {}
          "/programme/*":
            1376852400: [0, 0, 0] # 0 because we stubbed

        return cb()

    all.push ( cb ) =>
      # one hit for programme
      model.getCounters fetch_args..., ( err, counters ) =>
        @ok not null
        @deepEqual counters,
          "/brand/*/programme/*": {}
          "/programme/*":
            1376852400: 1

        return cb()

    # another hit for the same capture path
    all.push ( cb ) =>
      requestOptions =
        path: "/programme/bobthebuilder?api_key=phil"
        host: "programmes.api.localhost"

      @GET requestOptions, cb

    # counters should be up by one
    all.push ( cb ) =>
      # one hit for programme
      model.getCounters fetch_args..., ( err, counters ) =>
        @ok not null
        @deepEqual counters,
          "/brand/*/programme/*": {}
          "/programme/*":
            1376852400: 2

        return cb()

    # another hit for the same capture path
    all.push ( cb ) =>
      requestOptions =
        path: "/brand/bobthebuilder/programme/two?api_key=phil"
        host: "programmes.api.localhost"

      @GET requestOptions, cb

    # counters should be up by one
    all.push ( cb ) =>
      # one hit for programme
      model.getCounters fetch_args..., ( err, counters ) =>
        @ok not null
        @deepEqual counters,
          "/brand/*/programme/*":
            1376852400: 1
          "/programme/*":
            1376852400: 2

        return cb()

    async.series all, ( err ) =>
      @ok not err

      done 7