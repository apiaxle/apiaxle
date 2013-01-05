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
    options =
      key:  fs.readFileSync("test/key.pem"),
      cert: fs.readFileSync("test/cert.pem")

    app = express.createServer options

    app.get "/test", ( req, res ) ->
      console.log "TEST"
      console.log req

    app.listen 8000

    apiOptions =
      endPoint:  "127.0.0.1:8000"
      apiFormat: "json"
      protocol:  "https"

    # we create the API
    @fixtures.createApi "testhttps", apiOptions, ( err ) =>
      @isNull err

      keyOptions =
        forApi: "testhttps"

      @application.model( "keyFactory" ).create "1234", keyOptions, ( err ) =>
        @isNull err

        # make sure we don't actually hit facebook
        data = JSON.stringify
          one: 1

        @stubCatchall 200, data,
          "Content-Type": "application/json"

        requestOptions =
          path: "/test?apiaxle_key=1234&api_key=5678"
          host: "testhttps.api.localhost"

        @GET requestOptions, ( err, response ) =>
          @isNull err
          console.log err

          response.parseJson ( err, json ) =>
            @isNull err
            @equal json.one, 1

            done 5
