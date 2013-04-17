_     = require "lodash"
async = require "async"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.KeyStatsTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup api and key": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "json"

    # we create the API
    @fixtures.createApi "test_stats", apiOptions, ( err ) =>
      keyOptions =
        forApis: [ "test_stats" ]

      @fixtures.createKey "1234", keyOptions, ( err ) ->
        done()

  "test GET seconds stats for Key": ( done ) ->
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
      @GET path: "/v1/key/1234/stats?granularity=seconds&from=#{now_seconds}", ( err, res ) =>
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

          done 3

  "test GET minutes stats for Key": ( done ) ->
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
      @GET path: "/v1/key/1234/stats?granularity=minutes&from=#{now_seconds}", ( err, res ) =>
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

          done 3
