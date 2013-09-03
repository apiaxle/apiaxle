# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
_ = require "lodash"
url    = require "url"
async  = require "async"
libxml = require "libxmljs"

{ RedisMulti } = require "../../../../base/app/model/redis"
{ ApiaxleTest } = require "../../apiaxle"

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
          forApis: [ "programmes" ]

    @fixtures.create fixture, done

  "test timings are captured": ( done ) ->
    clock = @getClock 1323892867000

    requestOptions =
      path: "/?api_key=phil"
      host: "programmes.api.localhost"

    dnsStub = @stubDns { "programmes.api.localhost": "127.0.0.1" }
    httpStub = @stubCatchallSimpleGet 200, null,
      "Content-Type": "application/json"

    expire_list = {}
    expireStub = @getStub RedisMulti::, "expireat", ( key, ts ) =>
      expire_list[key] = ( ts - Math.floor( Date.now() / 1000 ) )

    all = []
    all.push ( cb ) =>
      @GET requestOptions, ( err, response ) =>
        @ok not err
        @ok dnsStub.calledOnce
        @ok httpStub.calledOnce

        model = @app.model "stattimers"
        names = [ "http-request" ]

        model.getValues [ "programmes" ], names, "hour", null, null, ( err, results ) =>
          @ok not err

          results = results["http-request"]

          @deepEqual results["1323892800"], [ 0, 0, 0 ]

          return cb()

    all.push ( cb ) =>
      # just move on
      clock.addHours 2

      @GET requestOptions, ( err, response ) =>
        @ok not err
        @ok dnsStub.calledTwice
        @ok httpStub.calledTwice

        model = @app.model "stattimers"
        names = [ "http-request" ]

        model.getValues [ "programmes" ], names, "hour", null, null, ( err, results ) =>
          @ok not err

          results = results["http-request"]

          @deepEqual results["1323892800"], [ 0, 0, 0 ]
          @deepEqual results["1323900000"], [ 0, 0, 0 ]

          console.log( expire_list )

          return cb()

    async.series all, ( err ) =>
      @ok not err

      done 12
