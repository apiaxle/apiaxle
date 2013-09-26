# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
_ = require "lodash"
url    = require "url"
nock = require "nock"
async  = require "async"
libxml = require "libxmljs"

{ RedisMulti } = require "../../../../base/app/model/redis"
{ ApiaxleTest } = require "../../apiaxle"
{ ApiaxleQueueProcessor } = require "../../../apiaxle-proxy-event-subscriber"

class exports.TimersTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup api/key": ( done ) ->
    fixture =
      api:
        programmes:
          endPoint: "bbc.co.uk"
      key:
        phil:
          qps: 200
          forApis: [ "programmes" ]

    @fixtures.create fixture, done

  "setup queue processor": ( done ) ->
    # this is a really poor hack, work out how to get the queue
    # processor running alongside the webserver somehow...
    @queue_proc = new ApiaxleQueueProcessor()

    @queue_proc.plugins = {}
    @queue_proc.plugins.models = @app.plugins.models

    # default options for @queue.processHit
    @default_queue_hit_options =
      api_name: "programmes"
      key_name: "phil"
      keyring_names: []
      pathname: "/programme/hello"
      timing:
        "start-request": 6
        "end-request": 20
      parsed_url:
        query: {}

    done()

  "test timings are captured": ( done ) ->
    clock = @getClock 1323892867000

    requestOptions =
      path: "/?api_key=phil"
      host: "programmes.api.localhost"

    dnsStub = @stubDns { "programmes.api.localhost": "127.0.0.1" }
    scope = nock( "http://bbc.co.uk" )
      .get( "/" )
      .twice()
      .reply( 200, "{}" )

    expire_list = {}
    expireStub = @getStub RedisMulti::, "expireat", ( key, ts ) =>
      expire_list[key] = ( ts - Math.floor( Date.now() / 1000 ) )

    all = []

    all.push ( cb ) =>
      @GET requestOptions, ( err, response ) =>
        @ok not err
        @ok dnsStub.calledOnce

        model = @app.model "stattimers"
        names = [ "http-request" ]

        @queue_proc.processHit @default_queue_hit_options, ( err ) =>
          @ok not err

          model.getValues [ "programmes" ], names, "hour", null, null, ( err, results ) =>
            @ok not err
            results = results["http-request"]
            @deepEqual results["1323892800"], [ 14, 14, 14 ]

            return cb()

    all.push ( cb ) =>
      # just move on
      clock.addHours 2

      @GET requestOptions, ( err, response ) =>
        @ok not err
        @ok scope.isDone(),
          "All nock scopes exhausted."
        @ok dnsStub.calledTwice

        opts = _.extend @default_queue_hit_options,
          timing:
            "start-request": 10
            "end-request": 20

        @queue_proc.processHit opts, ( err ) =>
          @ok not err

          model = @app.model "stattimers"
          names = [ "http-request" ]

          model.getValues [ "programmes" ], names, "hour", null, null, ( err, results ) =>
            @ok not err

            results = results["http-request"]

            @deepEqual results["1323892800"], [ 14, 14, 14 ]
            @deepEqual results["1323900000"], [ 10, 10, 10 ]

            return cb()

    async.series all, ( err ) =>
      @ok not err

      done 12
