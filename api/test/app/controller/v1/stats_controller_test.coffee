_     = require "lodash"
async = require "async"
querystring = require "querystring"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.KeyringStatsTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup fixtures": ( done ) ->
    fixtures =
      api:
        facebook:
          endPoint: "test"
        twitter:
          endPoint: "testagain"
      key:
        phil: {}
        frank: {}
        bob: {}
      keyring:
        trusted: {}
        untrusted: {}

    @fixtures.create fixtures, ( err, all ) ->
      throw err if err

      [ @facebook, @twitter,
        @phil, @frank, @bob,
        @trusted, @untrusted ] = all

      @trusted.linkKey "bob", ( err ) ->
        throw err if err

        done()

  #   bob (trusted)------------------> facebook
  #                `-----------------> twitter
  #
  #   frank (untrusted, trusted) ----> twitter

  "setup some hits": ( done ) ->
    model = @app.model "stats"
    hits  = []

    now = 1464951741939 # Fri, 03 Jun 2016

    @now_seconds = Math.floor( now / 1000 )
    @now_minutes = 1464951720
    @now_hours = 1464951600
    @now_days = 1464912000

    clock = @getClock now

    hits.push ( cb ) => model.hit "facebook", "bob", [ "trusted" ], "uncached", 200, cb
    hits.push ( cb ) => model.hit "facebook", "bob", [ "trusted"], "uncached", 200, cb

    hits.push ( cb ) => model.hit "facebook", "bob", [ "trusted" ], "cached", 400, cb
    hits.push ( cb ) => model.hit "facebook", "bob", [ "trusted" ], "cached", 400, cb

    hits.push ( cb ) => model.hit "twitter", "frank", [ "untrusted", "trusted" ], "cached", 400, cb
    hits.push ( cb ) => model.hit "facebook", "frank", [ "untrusted", "trusted" ], "uncached", 400, cb

    hits.push ( cb ) => model.hit "twitter", "frank", [ "untrusted", "trusted" ], "uncached", 200, cb
    hits.push ( cb ) => model.hit "twitter", "frank", [ "untrusted", "trusted" ], "uncached", 200, cb

    async.parallel hits, done

  "test getting apis scores": ( done ) ->
    path = "/v1/apis/charts"
    @GET path: path, ( err, res ) =>
      @ok not err

      res.parseJsonSuccess ( err, meta, charts ) =>
        @ok not err
        @deepEqual charts, { "facebook": 5, "twitter": 3 }

        done 3

  "test getting keys scores": ( done ) ->
    path = "/v1/keys/charts"
    @GET path: path, ( err, res ) =>
      @ok not err

      res.parseJsonSuccess ( err, meta, charts ) =>
        @ok not err
        @deepEqual charts, { "bob": 4, "frank": 4 }

        done 3

  "test getting api scores for a particular key": ( done ) ->
    path = "/v1/key/bob/apicharts"
    @GET path: path, ( err, res ) =>
      @ok not err

      res.parseJsonSuccess ( err, meta, charts ) =>
        @ok not err
        @deepEqual charts, { "facebook": 4 }

        done 3

  "test getting keys scores for a particular Api": ( done ) ->
    path = "/v1/api/facebook/keycharts"
    @GET path: path, ( err, res ) =>
      @ok not err

      res.parseJsonSuccess ( err, meta, charts ) =>
        @ok not err
        @deepEqual charts, { "bob": 4, "frank": 1 }

        done 3

  "test getting stats for a keyring": ( done ) =>
    all = []

    cases =
      untrusted: [
        {
          params: {}
          results:
            uncached: { 400: 1, 200: 2 }
            cached: { 400: 1 }
        },
        {
          params:
            forapi: "facebook"
          results:
            uncached: { 400: 1 }
        },
        {
          params:
            forapi: "twitter"
          results:
            uncached: { 200: 2 }
            cached: { 400: 1 }
        }
      ],
      trusted: [
        {
          params: {}
          results:
            uncached: { 400: 1, 200: 4 }
            cached: { 400: 3 }
        },
        {
          params:
            forapi: "facebook"
          results:
            uncached: { 400: 1, 200: 2 }
            cached: { 400: 2 }
        },
        {
          params:
            forapi: "twitter"
          results:
            uncached: { 200: 2 }
            cached: { 400: 1 }
        }
      ]

    for keyring, tests of cases
      for details in tests
        do( details, keyring ) =>
          all.push ( cb ) =>
            params = _.clone details.params
            params.from = @now_days
            params.granularity = "days"

            path = "/v1/keyring/#{ keyring }/stats?#{ querystring.stringify params }"
            @GET path: path, ( err, res ) =>
              @ok not err

              res.parseJsonSuccess ( err, meta, results ) =>
                @ok not err

                for field in [ "cached", "uncached", "error" ]
                  continue unless details.results[field]
                  @deepEqual details.results[field], results[field][@now_days]

                cb()

    async.series all, ( err ) =>
      @ok not err

      done 24

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

    hits.push ( cb ) => model.hit "facebook", "bob", [], "uncached", 200, cb
    hits.push ( cb ) => model.hit "facebook", "bob", [], "uncached", 200, cb

    hits.push ( cb ) => model.hit "facebook", "bob", [], "cached", 400, cb
    hits.push ( cb ) => model.hit "facebook", "bob", [], "cached", 400, cb

    hits.push ( cb ) => model.hit "facebook", "bill", [], "cached", 400, cb
    hits.push ( cb ) => model.hit "facebook", "bill", [], "uncached", 400, cb

    hits.push ( cb ) => model.hit "twitter", "bill", [], "uncached", 200, cb
    hits.push ( cb ) => model.hit "twitter", "bob", [], "uncached", 200, cb

    @test_cases = [ [ "seconds", @now_seconds ],
                    [ "minutes", @now_minutes ],
                    [ "hours",   @now_hours   ],
                    [ "days",    @now_days    ] ]

    async.parallel hits, done

  "test api stats at min, sec, hr, day level": ( done ) ->
    all = []

    for [ granularity, timestamp ] in @test_cases
      do ( granularity, timestamp ) =>
        all.push ( cb ) =>
          query =
            granularity: granularity
            from: @now_seconds

          path = "/v1/api/facebook/stats?#{ querystring.stringify query }"
          @GET path: path, ( err, res ) =>
            @ok not err

            res.parseJsonSuccess ( err, meta, results ) =>
              @ok not err

              @deepEqual results.uncached[timestamp], { 200: 2, 400: 1 }
              @deepEqual results.cached[timestamp], { 400: 3 }
              @deepEqual results.error, {}

              cb()

    async.series all, ( err ) =>
      @ok not err

      done 21

  "test api stats at min, sec, hr, day level narrowed by key": ( done ) ->
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
            @ok not err

            res.parseJson ( err, json ) =>
              @ok not err

              results = json.results

              @deepEqual results.uncached[timestamp], { 200: 2 }
              @deepEqual results.cached[timestamp], { 400: 2 }
              @deepEqual results.error, {}

              cb()

    async.series all, ( err ) =>
      @ok not err

      done 21

  "test key stats at min, sec, hr, day level": ( done ) ->
    all = []

    for [ granularity, timestamp ] in @test_cases
      do ( granularity, timestamp ) =>
        all.push ( cb ) =>
          query =
            granularity: granularity
            from: @now_seconds

          path = "/v1/key/bob/stats?#{ querystring.stringify query }"
          @GET path: path, ( err, res ) =>
            @ok not err

            res.parseJson ( err, json ) =>
              @ok not err

              results = json.results

              @deepEqual results.uncached[timestamp], { 200: 3 }
              @deepEqual results.cached[timestamp], { 400: 2 }
              @deepEqual results.error, {}

              cb()

    async.series all, ( err ) =>
      @ok not err

      done 21

  "test key stats at min, sec, hr, day level narrowed by api": ( done ) ->
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
            @ok not err

            res.parseJson ( err, json ) =>
              @ok not err

              results = json.results

              @deepEqual results.uncached[timestamp], { 200: 1 }
              @deepEqual results.cached, {}
              @deepEqual results.error, {}

              cb()

    async.series all, ( err ) =>
      @ok not err

      done 21

  "test api stats at min, sec, hr, day level with timeseries output": ( done ) ->
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
            @ok not err

            res.parseJson ( err, json ) =>
              @ok not err

              results = json.results

              @deepEqual results.uncached["200"][timestamp], 2
              @deepEqual results.uncached["400"][timestamp], 1
              @deepEqual results.cached["400"][timestamp], 3
              @deepEqual results.error, {}

              cb()

    async.series all, ( err ) =>
      @ok not err

      done 25
