# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
_ = require "lodash"
url    = require "url"
async  = require "async"
libxml = require "libxmljs"
nock = require "nock"

{ ApiaxleTest } = require "../../apiaxle"
{ RedisMulti } = require "../../../../base/app/model/redis"
{ ApiaxleQueueProcessor } = require "../../../apiaxle-proxy-event-subscriber"

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

  "setup queue processor": ( done ) ->
    # this is a really poor hack, work out how to get the queue
    # processor running alongside the webserver somehow...
    @queue_proc = new ApiaxleQueueProcessor()

    @queue_proc.plugins = {}
    @queue_proc.plugins.models = @app.plugins.models

    done()

  "test timings/counters are captured": ( done ) ->
    dnsStub = @stubDns { "programmes.api.localhost": "127.0.0.1" }

    all = []

    # fix the clock and stop things expiring
    clock = @getClock 1376854000000
    now = Math.floor( Date.now() / 1000 )
    stub = @getStub RedisMulti::, "expireat", ->

    fetch_args = [ [ "api", "programmes" ], @captures, "hour", now - 2000, null ]

    model = @app.model "capturepaths"

    # default options for @queue.processHit
    default_queue_hit_options =
      api_name: "programmes"
      key_name: "phil"
      keyring_names: []
      timing:
        "start-request": 6
        "end-request": 10
        "first": Date.now()
      parsed_url:
        query: {}

    scope1 = null
    scope2 = null
    scope3 = null

    # test that hitting root DOES log as a capture
    all.push ( cb ) =>
      scope1 = nock( "http://bbc.co.uk" )
        .get( "/programme/toystory" )
        .once()
        .reply( 200, "{}" )

      requestOptions =
        path: "/programme/toystory?api_key=phil"
        host: "programmes.api.localhost"

      @GET requestOptions, cb

    # need to fake the pub/sub thing happening. See above about this
    # being a bit of a hack...
    all.push ( cb ) =>
      opts = _.extend default_queue_hit_options,
        parsed_url:
          pathname: "/programme/toystory"

      return @queue_proc.processHit opts, cb

    all.push ( cb ) =>
      # one set of timings
      model.getTimers fetch_args..., ( err, timings ) =>
        @ok not null
        @deepEqual timings,
          "/brand/*/programme/*": {}
          "/programme/*":
            1376852400: [4, 4, 4]

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
      scope2 = nock( "http://bbc.co.uk" )
        .get( "/programme/bobthebuilder" )
        .once()
        .reply( 200, "{}" )

      requestOptions =
        path: "/programme/bobthebuilder?api_key=phil"
        host: "programmes.api.localhost"

      @GET requestOptions, cb

    # account for the new hit above
    all.push ( cb ) =>
      opts = _.extend default_queue_hit_options,
        parsed_url:
          pathname: "/programme/bobthebuilder"

      return @queue_proc.processHit opts, cb

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
      scope3 = nock( "http://bbc.co.uk" )
        .get( "/brand/bobthebuilder/programme/two" )
        .once()
        .reply( 200, "{}" )

      requestOptions =
        path: "/brand/bobthebuilder/programme/two?api_key=phil"
        host: "programmes.api.localhost"

      @GET requestOptions, cb

    # account for the next hit
    all.push ( cb ) =>
      opts = _.extend default_queue_hit_options,
        parsed_url:
          pathname: "/brand/bobthebuilder/programme/two"

      return @queue_proc.processHit opts, cb

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
      @ok scope1.isDone()
      @ok scope2.isDone()
      @ok scope3.isDone()

      done 12
