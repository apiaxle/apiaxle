_     = require "underscore"
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

    now = ( new Date ).getTime()
    now_seconds = Math.floor( now/1000 )
    clock = @getClock now

    hits.push ( cb ) => model.hit "test_stats", "1234", "uncached", 200, cb
    hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb
    hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb

    async.parallel hits, ( err, results ) =>
      @isNull err
      @GET path: "/v1/api/test_stats/stats?granularity=minutes&from=#{now_seconds}", ( err, res ) =>
        res.parseJson ( err, json ) =>
          @isNull err
          @ok json

          # A little bit complex as the ts may have shifted by 1
          for code, result of json.results.uncached
            @equal code, 200
            for ts, count of result
              @equal count, 1

          for code, result of json.results.cached
            @equal code, 400
            for ts, count of result
              @ok count > 0

          done 7

  "test GET seconds stats for API": ( done ) ->
    model = @app.model "stats"
    hits  = []
    # Wed, December 14th 2011, 20:01
    now = ( new Date ).getTime()
    now_seconds = Math.floor( now/1000 )
    clock = @getClock now

    hits.push ( cb ) => model.hit "test_stats", "1234", "uncached", 200, cb
    hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb
    hits.push ( cb ) => model.hit "test_stats", "1234", "cached", 400, cb

    async.parallel hits, ( err, results ) =>
      @isNull err
      @GET path: "/v1/api/test_stats/stats?granularity=seconds&from=#{now_seconds}", ( err, res ) =>
        res.parseJson ( err, json ) =>
          @isNull err
          @ok json

          # A little bit complex as the ts may have shifted by 1
          for code, result of json.results.uncached
            @equal code, 200
            for ts, count of result
              @equal count, 1

          for code, result of json.results.cached
            @equal code, 400
            for ts, count of result
              @ok count > 0

          done 7

  "test invalid granularity input": ( done ) ->
    @GET path: "/v1/api/test_stats/stats?granularity=nanoparsecs", ( err, res ) =>
      @isNull err

      res.parseJson ( err, json ) =>
        @isNull err
        @ok error = json.results.error

        @equal error.message, "Valid granularities are seconds, minutes, hours, days"
        @equal error.type, "InvalidGranularityType"
        @equal res.statusCode, 400
        @equal json.meta.status_code, 400

        done 7
