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

  "test GET/POST/PUT https with valid api_key": ( done ) ->
    test_server = express.createServer
      key:  fs.readFileSync("test/key.pem"),
      cert: fs.readFileSync("test/cert.pem")

    test_server.use express.bodyParser()

    for method in [ "get", "post", "put" ]
      do( method ) ->
        # setup a test endpoint e.g /test/get which retuns various
        # aspects of the call so that we can test them
        test_server[ method ] "/test/#{ method }", ( req, res ) ->
          res.send JSON.stringify
            method: method
            body: req.body

    test_server.listen 8000

    fixture =
      api:
        testhttps:
          endPoint:  "127.0.0.1:8000"
          apiFormat: "json"
          protocol:  "https"
      key:
        1234:
          forApis: [ "testhttps" ]
          qps: 200

    @fixtures.create fixture, ( err ) =>
      @isNull err

      stub = @stubDns { "testhttps.api.localhost": "127.0.0.1" }

      all_methods = []

      # now test the methods themselves
      all_methods.push ( cb ) =>
        requestOptions =
          path: "/test/post?apiaxle_key=1234&api_key=5678"
          host: "testhttps.api.localhost"
          headers:
            "Content-Type": "application/json"
          data: JSON.stringify "this is a post body"

        @POST requestOptions, ( err, response ) =>
          # twice because we make one DNS call to the proxy, then the
          # proxy makes another call to the service running on port 8000
          @ok stub.calledTwice

          response.parseJson ( err, json ) =>
            @isNull err
            @equal json.method, "post"
            @equal json.body, "this is a post body"

            cb()

      all_methods.push ( cb ) =>
        requestOptions =
          path: "/test/put?apiaxle_key=1234&api_key=5678"
          host: "testhttps.api.localhost"
          headers:
            "Content-Type": "application/json"
          data: JSON.stringify "this is a put body"

        @PUT requestOptions, ( err, response ) =>
          response.parseJson ( err, json ) =>
            @isNull err
            @equal json.method, "put"
            #@equal json.body, "this is a put body"

            cb()

      all_methods.push ( cb ) =>
        requestOptions =
          path: "/test/get?apiaxle_key=1234&api_key=5678"
          host: "testhttps.api.localhost"

        @GET requestOptions, ( err, response ) =>
          response.parseJson ( err, json ) =>
            @isNull err
            @equal json.method, "get"

            cb()

      async.series all_methods, ( err ) =>
        @isNull err

        # make sure we stop the server listening
        test_server.close()

        done 10
