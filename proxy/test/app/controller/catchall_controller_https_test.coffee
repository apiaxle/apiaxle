async   = require "async"
libxml  = require "libxmljs"
express = require "express"
https   = require "https"
crypto  = require "crypto"
fs      = require "fs"

{ ApiaxleTest } = require "../../apiaxle"

class exports.CatchallHTTPSTest extends ApiaxleTest
  @start_webserver   = true
  @empty_db_on_setup = true

  "test GET https with valid api_key": ( done ) ->
    test_server = express.createServer
      key:  fs.readFileSync("test/key.pem"),
      cert: fs.readFileSync("test/cert.pem")

    test_server.get "/test", ( req, res ) ->
      res.send JSON.stringify
        one: 1

    test_server.listen 8000

    fixture =
      api:
        testhttps:
          endPoint:  "127.0.0.1:8000"
          apiFormat: "json"
          protocol:  "https"
      key:
        1234:
          forApi: "testhttps"

    @fixtures.create fixture, ( err ) =>
      @isNull err

      requestOptions =
        path: "/test?apiaxle_key=1234&api_key=5678"
        host: "testhttps.api.localhost"

      stub = @stubDns { "testhttps.api.localhost": "127.0.0.1" }

      @GET requestOptions, ( err, response ) =>
        @isNull err

        # twice because we make one DNS call to the proxy, then the
        # proxy makes another call to the service running on port 8000
        @ok stub.calledTwice

        # make sure we stop the server listening
        test_server.close()

        response.parseJson ( err, json ) =>
          @isNull err
          @equal json.one, 1

          done 5
