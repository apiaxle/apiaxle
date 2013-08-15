# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
_ = require "lodash"
url    = require "url"
async  = require "async"
libxml = require "libxmljs"

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
    requestOptions =
      path: "/?api_key=phil"
      host: "programmes.api.localhost"

    dnsStub = @stubDns { "programmes.api.localhost": "127.0.0.1" }
    stub = @stubCatchallSimpleGet 200, null,
      "Content-Type": "application/json"

    @GET requestOptions, ( err, response ) =>
      @ok not err
      @ok dnsStub.calledOnce

      model = @app.model "stattimers"
      names = [ "http-request" ]

      model.getCounterValues "programmes", names, "hour", null, null, ( err, results ) =>
        @ok not err

        results = results["http-request"]

        @ok not _.isEmpty results
        @ok times = _.keys( results )
        @equal times.length, 1

        @ok values = results[times[0]]
        @equal values.length, 3

        done 8
