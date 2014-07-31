# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
_ = require "lodash"
async = require "async"
querystring = require "querystring"

{ ApiaxleTest } = require "../../../apiaxle"
{ RedisMulti } = require "../../../../../base/app/model/redis"

class exports.ApiStatsCaptureControllerTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup stubs": ( done ) ->
    # avoid stuff expiring its way out of redis
    stub = @getStub RedisMulti::, "expireat", ->

    # fix the clock
    @clock = @getClock 1376854000000
    @now = Math.floor( Date.now() / 1000 )

    done()

  "setup api and capture paths": ( done ) ->
    fixtures =
      api:
        facebook:
          endPoint: "graph.facebook.com"
      key:
        phil:
          forApis: [ "facebook" ]
        bob:
          forApis: [ "facebook" ]
      keyring:
        ring1: {}
        ring2: {}
        ring3: {}

    @fixtures.create fixtures, ( err, details ) =>
      throw err if err

      [ @facebook, @phil, @bob, @ring1, @ring2, @ring3 ] = details

      all = []
      all.push ( cb ) => @ring1.linkKey "phil", cb
      all.push ( cb ) => @ring2.linkKey "bob", cb

      all.push ( cb ) => @ring3.linkKey "bob", cb
      all.push ( cb ) => @ring3.linkKey "phil", cb

      all.push ( cb ) => @facebook.addCapturePath "/animal/noise", cb

      async.series all, done

  "test fetching capture paths": ( done ) ->
    @GET path: "/v1/api/facebook/capturepaths", ( err, res ) =>
      @ok not err

      res.parseJsonSuccess ( err, meta, paths ) =>
        @ok not err
        @ok paths
        @deepEqual paths, [ "/animal/noise" ]

        done 4

  "test adding capture paths": ( done ) ->
    @PUT path: "/v1/api/facebook/addcapturepath/%2Fanimal%2Fnoise%2F*", ( err, res ) =>
      @ok not err

      res.parseJsonSuccess ( err, meta, ok ) =>
        @ok not err
        @ok ok

        # now there should be two
        @GET path: "/v1/api/facebook/capturepaths", ( err, res ) =>
          @ok not err

          res.parseJsonSuccess ( err, meta, paths ) =>
            @ok not err
            @deepEqual paths.sort(), [ "/animal/noise", "/animal/noise/*" ]

            done 6

  "test deleting capture paths": ( done ) ->
    @PUT path: "/v1/api/facebook/delcapturepath/%2Fanimal%2Fnoise", ( err, res ) =>
      @ok not err

      res.parseJsonSuccess ( err, meta, ok ) =>
        @ok not err
        @ok ok

        # now there should be none
        @GET path: "/v1/api/facebook/capturepaths", ( err, res ) =>
          @ok not err

          res.parseJsonSuccess ( err, meta, paths ) =>
            @ok not err
            @deepEqual paths, []

            done 6

  "test requesting statistical information": ( done ) ->
    hits = []

    # add a new path to facebook
    hits.push ( cb ) => @facebook.addCapturePath "/animal/noise/*", cb

    # make a couple of hits on behalf of phil...
    hits.push ( cb ) =>
      args = [
        @facebook.id,
        @phil.id,
        [ @ring1.id, @ring3.id ],
        [ "/animal/noise", "/animal/noise/*" ],
        100,
        Date.now()
      ]

      @app.model( "capturepaths" ).log args..., cb

    # ...and then bob
    hits.push ( cb ) =>
      args = [
        @facebook.id,
        @bob.id,
        [ @ring2.id, @ring3.id ]
        [ "/animal/noise" ]
        200,
        Date.now()
      ]

      @app.model( "capturepaths" ).log args..., cb

    async.series hits, ( err ) =>
      @ok not err

      # 1376853960
      expectations = []
      expectations.push
        request:
          path: "/v1/api/facebook/capturepaths/stats/timers"
          query:
            granularity: "day"
            from: "1376853900"
        result:
          "/animal/noise":
            1376784000: [ 100, 200, 150 ]
          "/animal/noise/*":
            1376784000: [ 100, 100, 100 ]

      expectations.push
        request:
          path: "/v1/api/facebook/capturepaths/stats/counters"
          query:
            granularity: "day"
            from: "1376853900"
        result:
          "/animal/noise":
            1376784000: 2
          "/animal/noise/*":
            1376784000: 1

      expectations.push
        request:
          path: "/v1/api/facebook/capturepaths/stats/counters"
          query:
            granularity: "day"
            from: "1376853900"
            forkeyring: "ring3"
        result:
          "/animal/noise":
            1376784000: 2
          "/animal/noise/*":
            1376784000: 1

      expectations.push
        request:
          path: "/v1/api/facebook/capturepaths/stats/counters"
          query:
            granularity: "day"
            from: "1376853900"
            forkeyring: "ring1"
        result:
          "/animal/noise":
            1376784000: 1
          "/animal/noise/*":
            1376784000: 1

      expectations.push
        request:
          path: "/v1/api/facebook/capturepaths/stats/counters"
          query:
            granularity: "day"
            from: "1376853900"
            forkey: "phil"
        result:
          "/animal/noise":
            1376784000: 1
          "/animal/noise/*":
            1376784000: 1

      expectations.push
        request:
          path: "/v1/api/facebook/capturepaths/stats/counters"
          query:
            granularity: "day"
            from: "1376853900"
            forkey: "bob"
        result:
          "/animal/noise":
            1376784000: 1
          "/animal/noise/*": {}

      expectations.push
        request:
          path: "/v1/api/facebook/capturepaths/stats/counters"
          query:
            granularity: "day"
            from: "1376853900"
            forkeyring: "ring2"
        result:
          "/animal/noise":
            1376784000: 1
          "/animal/noise/*": {}

      expectations.push
        request:
          path: "/v1/api/facebook/capturepath/%2Fanimal%2Fnoise/stats/timers"
          query:
            granularity: "day"
            from: "1376853900"
        result:
          "/animal/noise":
            1376784000: [ 100, 200, 150 ]

      expectations.push
        request:
          path: "/v1/api/facebook/capturepath/%2Fanimal%2Fnoise/stats/counters"
          query:
            granularity: "day"
            from: "1376853900"
        result:
          "/animal/noise":
            1376784000: 2

      expectations.push
        request:
          path: "/v1/api/facebook/capturepath/%2Fanimal%2Fnoise/stats/counters"
          query:
            granularity: "day"
            from: "1376853900"
            forkey: "bob"
        result:
          "/animal/noise":
            1376784000: 1

      expectations.push
        request:
          path: "/v1/api/facebook/capturepath/%2Fanimal%2Fnoise%2F*/stats/timers"
          query:
            granularity: "day"
            from: "1376853900"
        result:
          "/animal/noise/*":
            1376784000: [ 100, 100, 100 ]

      expectations.push
        request:
          path: "/v1/api/facebook/capturepath/%2Fanimal%2Fnoise%2F*/stats/counters"
          query:
            granularity: "day"
            from: "1376853900"
        result:
          "/animal/noise/*":
            1376784000: 1

      all = []
      for details in expectations
        do( details ) =>
          all.push ( cb ) =>
            { request, result } = details

            path = "#{ request.path }?#{ querystring.stringify request.query }"

            @GET path: path, ( err, res ) =>
              @ok not err

              res.parseJsonSuccess ( err, meta, paths ) =>
                @ok not err
                @deepEqual paths, result

                cb()

      async.parallel all, ( err ) =>
        @ok not err

        done 38
