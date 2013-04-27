url = require "url"
async = require "async"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.ApisControllerTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup fixtures": ( done ) ->
    # create 11 apis
    fixtures = []
    model = @app.model( "apifactory" )

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          options =
            globalCache: i
            endPoint: "api_#{i}.com"

          model.create "api_#{i}", options, cb

    async.series fixtures, done

  "test list apis without resolution": ( done ) ->
    @GET path: "/v1/apis?from=1&to=12", ( err, response ) =>
      @ok not err

      response.parseJson ( err, json ) =>
        @ok not err
        @ok json
        @equal json.results.length, 10

        # no next because we're asking for more than 10 results
        @isUndefined json.meta.pagination.next
        parsed = url.parse json.meta.pagination.prev, true

        @equal "#{ parsed.protocol }//#{ parsed.host }", @host_name
        @deepEqual parsed.query,
          from: 0
          to: 1
          resolve: "false"

        done 7

  "test list apis with resolution": ( done ) ->
    @GET path: "/v1/apis?from=0&to=5&resolve=true", ( err, response ) =>
      @ok not err

      response.parseJson ( err, json ) =>
        @ok not err
        @ok json

        # no next because we're asking for more than 10 results
        @isUndefined json.meta.pagination.prev
        parsed = url.parse json.meta.pagination.next, true

        @equal "#{ parsed.protocol }//#{ parsed.host }", @host_name
        @deepEqual parsed.query,
          from: 6
          to: 12
          resolve: "true"

        for i in [ 0..5 ]
          name = "api_#{i}"

          @ok json.results[ name ]
          @equal json.results[ name ].globalCache, i
          @equal json.results[ name ].endPoint, "api_#{i}.com"

        done 24
