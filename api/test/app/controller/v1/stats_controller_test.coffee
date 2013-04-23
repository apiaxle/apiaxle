_     = require "lodash"
async = require "async"
querystring = require "querystring"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.ApiStatsTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup api and key": ( done ) ->
    fixtures =
      api:
        facebook:
          endPoint:  "graph.facebook.com"
        twitter:
          endPoint:  "api.twitter.com"
      key:
        bob: {}
        bill: {}

    @fixtures.create fixtures, done

  "setup some hits": ( done ) ->
    model = @app.model "stats"
    hits  = []

    now = 1464951741939 # Fri, 03 Jun 2016

    @now_seconds = Math.floor( now / 1000 )
    @now_minutes = 1464951720
    @now_hours = 1464951600
    @now_days = 1464912000

    clock = @getClock now

    hits.push ( cb ) => model.hit "facebook", "bob", "uncached", 200, cb
    hits.push ( cb ) => model.hit "facebook", "bob", "uncached", 200, cb

    hits.push ( cb ) => model.hit "facebook", "bob", "cached", 400, cb
    hits.push ( cb ) => model.hit "facebook", "bob", "cached", 400, cb

    hits.push ( cb ) => model.hit "facebook", "bill", "cached", 400, cb
    hits.push ( cb ) => model.hit "facebook", "bill", "uncached", 400, cb

    hits.push ( cb ) => model.hit "twitter", "bill", "uncached", 200, cb
    hits.push ( cb ) => model.hit "twitter", "bob", "uncached", 200, cb

    @test_cases = [ [ "seconds", @now_seconds ],
                    [ "minutes", @now_minutes ],
                    [ "hours",   @now_hours   ],
                    [ "days",    @now_days    ] ]

    async.parallel hits, done

  "test api stats at minute,second,hour,day level": ( done ) ->
    all = []

    for [ granularity, timestamp ] in @test_cases
      do ( granularity, timestamp ) =>
        all.push ( cb ) =>
          query =
            granularity: granularity
            from: @now_seconds

          path = "/v1/api/facebook/stats?#{ querystring.stringify query }"
          @GET path: path, ( err, res ) =>
            @isNull err

            res.parseJson ( err, json ) =>
              @isNull err

              results = json.results

              @deepEqual results.uncached[timestamp], { 200: 2, 400: 1 }
              @deepEqual results.cached[timestamp], { 400: 3 }
              @deepEqual results.error, {}

              cb()

    async.series all, ( err ) =>
      @isNull err

      done 21

  "test api stats at minute,second,hour,day level narrowed by key": ( done ) ->
    all = []

    for [ granularity, timestamp ] in @test_cases
      do ( granularity, timestamp ) =>
        all.push ( cb ) =>
          query =
            granularity: granularity
            from: @now_seconds
            forkey: "bob"

          path = "/v1/api/facebook/stats?#{ querystring.stringify query }"
          @GET path: path, ( err, res ) =>
            @isNull err

            res.parseJson ( err, json ) =>
              @isNull err

              results = json.results

              @deepEqual results.uncached[timestamp], { 200: 2 }
              @deepEqual results.cached[timestamp], { 400: 2 }
              @deepEqual results.error, {}

              cb()

    async.series all, ( err ) =>
      @isNull err

      done 21

  "test key stats at minute,second,hour,day level": ( done ) ->
    all = []

    for [ granularity, timestamp ] in @test_cases
      do ( granularity, timestamp ) =>
        all.push ( cb ) =>
          query =
            granularity: granularity
            from: @now_seconds

          path = "/v1/key/bob/stats?#{ querystring.stringify query }"
          @GET path: path, ( err, res ) =>
            @isNull err

            res.parseJson ( err, json ) =>
              @isNull err

              results = json.results

              @deepEqual results.uncached[timestamp], { 200: 3 }
              @deepEqual results.cached[timestamp], { 400: 2 }
              @deepEqual results.error, {}

              cb()

    async.series all, ( err ) =>
      @isNull err

      done 21

  "test key stats at minute,second,hour,day level narrowed by api": ( done ) ->
    all = []

    for [ granularity, timestamp ] in @test_cases
      do ( granularity, timestamp ) =>
        all.push ( cb ) =>
          query =
            granularity: granularity
            from: @now_seconds
            forapi: "twitter"

          path = "/v1/key/bill/stats?#{ querystring.stringify query }"
          @GET path: path, ( err, res ) =>
            @isNull err

            res.parseJson ( err, json ) =>
              @isNull err

              results = json.results

              @deepEqual results.uncached[timestamp], { 200: 1 }
              @deepEqual results.cached, {}
              @deepEqual results.error, {}

              cb()

    async.series all, ( err ) =>
      @isNull err

      done 21

  "test api stats at minute,second,hour,day level with timeseries output": ( done ) ->
    all = []

    for [ granularity, timestamp ] in @test_cases
      do ( granularity, timestamp ) =>
        all.push ( cb ) =>
          query =
            granularity: granularity
            from: @now_seconds
            format_timeseries: true

          path = "/v1/api/facebook/stats?#{ querystring.stringify query }"
          @GET path: path, ( err, res ) =>
            @isNull err

            res.parseJson ( err, json ) =>
              @isNull err

              results = json.results

              @deepEqual results.uncached["200"][timestamp], 2
              @deepEqual results.uncached["400"][timestamp], 1
              @deepEqual results.cached["400"][timestamp], 3
              @deepEqual results.error, {}

              cb()

    async.series all, ( err ) =>
      @isNull err

      done 25
