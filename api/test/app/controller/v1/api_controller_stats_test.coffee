_     = require "lodash"
async = require "async"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.ApiStatsTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup api and key": ( done ) ->
    fixtures =
      api:
        test_stats:
          endPoint:  "graph.facebook.com"
          apiFormat: "json"
      key:
        1234: {}

    @fixtures.create fixtures, done

  "test GET minute stats for API": ( done ) ->
    model = @app.model "stats"
    hits  = []

    # this needs to be in the future because redis will expire a key
    # in the past instantly
    now = 1464951741939         # Fri, 03 Jun 2016
    now_seconds = Math.floor( now / 1000 )
    clock = @getClock now

    last_minute = 1464951720

    hits.push ( cb ) => model.hit "test_stats", "1234", "uncached", 200, cb
    hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb
    hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb

    async.parallel hits, ( err, results ) =>
      @isNull err

      from = now_seconds
      to = now_seconds + 500

      @GET path: "/v1/api/test_stats/stats?granularity=minutes&from=#{from}&to=#{to}", ( err, res ) =>
        @isNull err

        res.parseJson ( err, json ) =>
          @isNull err
          @ok json

          @equal json.results.cached[ last_minute ]["400"], 2
          @equal json.results.uncached[ last_minute ]["200"], 1

          done 6

  "test GET seconds stats for API": ( done ) ->
    model = @app.model "stats"
    hits  = []

    now = ( new Date ).getTime()
    now_seconds = Math.floor( now/1000 )
    clock = @getClock now

    hits.push ( cb ) => model.hit "test_stats", "1234", "uncached", 200, cb
    hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb
    hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb

    async.parallel hits, ( err, results ) =>
      @isNull err

      @GET path: "/v1/api/test_stats/stats?granularity=seconds&from=#{now_seconds}", ( err, res ) =>
        @isNull err

        res.parseJson ( err, json ) =>
          @isNull err
          @ok json

          # a little bit complex as the ts may have shifted by 1
          @equal json.results.cached[ now_seconds ]["400"], 2
          @equal json.results.uncached[ now_seconds ]["200"], 1

          done 6

  "test invalid granularity input": ( done ) ->
    @GET path: "/v1/api/test_stats/stats?granularity=nanoparsecs", ( err, res ) =>
      @isNull err

      res.parseJson ( err, json ) =>
        @isNull err
        @ok error = json.results.error

        @equal error.message, "granularity: Value of the ‘granularity’ must be seconds or minutes or hours or days."
        @equal error.type, "ValidationError"
        @equal res.statusCode, 400
        @equal json.meta.status_code, 400

        done 7

  "test GET seconds stats for API in timeseries format": ( done ) ->
    model = @app.model "stats"
    hits  = []

    now = ( new Date ).getTime()
    now_seconds = Math.floor( now/1000 )
    clock = @getClock now

    hits.push ( cb ) => model.hit "test_stats", "1234", "uncached", 200, cb
    hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb
    hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb

    async.parallel hits, ( err, results ) =>
      @isNull err

      path = "/v1/api/test_stats/stats?granularity=seconds&from=#{now_seconds}"
      path += "&format_timeseries=true"

      @GET path: path, ( err, res ) =>
        @isNull err

        res.parseJson ( err, json ) =>
          @isNull err
          @ok json

          # a little bit complex as the ts may have shifted by 1
          @equal json.results.cached["400"][ now_seconds ], 2
          @equal json.results.uncached["200"][ now_seconds ], 1

          done 6