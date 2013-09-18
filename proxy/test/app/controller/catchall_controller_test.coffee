# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
url    = require "url"
async  = require "async"
libxml = require "libxmljs"

{ ApiaxleTest } = require "../../apiaxle"

class exports.CatchallTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "test disabled API causes error": ( done ) ->
    fixture =
      api:
        programmes:
          endPoint: "bbc.co.uk"
          defaultPath: "/tv/programmes"
          disabled: true
      key:
        phil:
          forApis: [ "programmes" ]

    @fixtures.create fixture, ( err, [ api, key ] ) =>
      @ok not err

      requestOptions =
        path: "/?api_key=phil"
        host: "programmes.api.localhost"

      @stubDns { "programmes.api.localhost": "127.0.0.1" }
      @GET requestOptions, ( err, response ) =>
        @ok not err
        @equal response.statusCode, 400

        response.parseJson ( err, json ) =>
          @ok error = json.results.error
          @equal error.type, "ApiDisabled"
          @equal error.message, "This API has been disabled."

          done 6

  "test disabled Key causes error": ( done ) ->
    fixture =
      api:
        programmes:
          endPoint: "bbc.co.uk"
          defaultPath: "/tv/programmes"
      key:
        phil:
          forApis: [ "programmes" ]
          disabled: true

    @fixtures.create fixture, ( err, [ api, key ] ) =>
      @ok not err

      requestOptions =
        path: "/?api_key=phil"
        host: "programmes.api.localhost"

      @stubDns { "programmes.api.localhost": "127.0.0.1" }
      @GET requestOptions, ( err, response ) =>
        @ok not err
        @equal response.statusCode, 401

        response.parseJson ( err, json ) =>
          @ok error = json.results.error
          @equal error.type, "KeyDisabled"
          @equal error.message, "This API key has been disabled."

          done 6

  "test defaultPath functionality": ( done ) ->
    fixture =
      api:
        programmes:
          endPoint: "bbc.co.uk"
          defaultPath: "/tv/programmes"
      key:
        phil:
          forApis: [ "programmes" ]

    @fixtures.create fixture, ( err, [ api, key ] ) =>
      @ok not err

      stub = @stubCatchall ( options, api, key, keyrings, cb ) =>
        { path, query } = url.parse options.url
        @equal path, "/tv/programmes/genres/drama/scifiandfantasy/schedules/upcoming.json"
        @fakeIncomingMessage 200, {}, {}, cb

      requestOptions =
        path: "/genres/drama/scifiandfantasy/schedules/upcoming.json?api_key=phil"
        host: "programmes.api.localhost"

      @stubDns { "programmes.api.localhost": "127.0.0.1" }
      @GET requestOptions, ( err, response ) =>
        @ok not err

        done 3

  "test sendThroughApiSig functionality": ( done ) ->
    fixtures =
      api:
        programmes:
          endPoint: "example.com"
          sendThroughApiSig: true
        facebook:
          endPoint: "example.com"
          sendThroughApiKey: true
        twitter:
          endPoint: "example.com"
      key:
        phil:
          forApis: [ "programmes", "facebook", "twitter" ]

    expects =
      facebook:
        expected_path: "/?api_key=phil"
      twitter:
        expected_path: "/"
      programmes:
        expected_path: "/?api_key=phil&api_sig=bob"

    @fixtures.create fixtures, ( err, [ bbc, facebook, key ] ) =>
      @ok not err

      @stubDns {
        "facebook.api.localhost": "127.0.0.1"
        "programmes.api.localhost": "127.0.0.1"
        "twitter.api.localhost": "127.0.0.1"
      }

      all = []
      for api_name, details of expects
        do( api_name, details ) =>
          all.push ( cb ) =>
            stub = @stubCatchall ( options, api, key, keyrings, cb ) =>
              { path, query } = url.parse options.url
              @equal path, details.expected_path
              @fakeIncomingMessage 200, {}, {}, cb

            requestOptions =
              path: "/?api_key=phil&api_sig=bob"
              host: "#{ api_name }.api.localhost"

            @GET requestOptions, ( err, res ) =>
              @ok not err
              stub.restore()
              cb()

      async.series all, ( err ) =>
        @ok not err

        done 7

  "test POST,GET,PUT and DELETE with no subdomain": ( done ) ->
    all = []

    for method in [ "POST", "GET", "PUT", "DELETE" ]
      do ( method ) =>
        all.push ( cb ) =>
          options =
            method: method
            path: "/"
            data: "something"

          @httpRequest options, ( err, response ) =>
            @ok not err
            @ok response
            @equal response.statusCode, 404

            response.parseJson ( err, json ) =>
              @ok not err
              # meta
              @equal json.meta.version, 1
              @equal json.meta.status_code, response.statusCode

              @ok json.results.error
              @equal json.results.error.type, "ApiUnknown"

              cb()

    async.parallel all, ( err, results ) =>
      @ok not err
      @equal results.length, 4

      done 34

  "test POST,GET,PUT and DELETE with unregistered domain": ( done ) ->
    all = []

    @stubDns { "twitter.api.localhost": "127.0.0.1" }

    for method in [ "POST", "GET", "PUT", "DELETE" ]
      do ( method ) =>
        all.push ( cb ) =>
          options =
            method: method
            hostname: "twitter.api.localhost"
            path: "/?api_key=1234"
            data: "something"

          @httpRequest options, ( err, response ) =>
            @ok not err

            @ok response
            @equal response.statusCode, 404

            response.parseJson ( err, json ) =>
              @ok not err
              @ok json.results.error
              @equal json.results.error.type, "ApiUnknown"

              cb()

    async.series all, ( err, results ) =>
      @ok not err
      @equal results.length, 4

      done 26

  "test GET with registered domain but no key": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "json"

    @stubDns { "facebook.api.localhost": "127.0.0.1" }

    # we create the API
    @fixtures.createApi "facebook", apiOptions, ( err ) =>
      @ok not err

      @GET { path: "/", host: "facebook.api.localhost" }, ( err, response ) =>
        @ok not err

        response.parseJson ( err, json ) =>
          @ok not err
          @ok err = json.results.error
          @equal err.type, "KeyError"

          done 5

  "test GET with registered domain but invalid key": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "json"

    # we create the API
    @fixtures.createApi "facebook", apiOptions, ( err ) =>
      @ok not err

      @stubDns { "facebook.api.localhost": "127.0.0.1" }
      @GET { path: "/?api_key=1", host: "facebook.api.localhost" }, ( err, response ) =>
        response.parseJson ( err, json ) =>
          @ok not err
          @ok err = json.results.error
          @equal err.type, "KeyError"

          done 4

  "test GET with registered domain and valid key": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "json"

    # we create the API
    @fixtures.createApi "facebook", apiOptions, ( err ) =>
      @ok not err

      keyOptions =
        forApis: [ "facebook" ]

      @app.model( "keyfactory" ).create "1234", keyOptions, ( err ) =>
        @ok not err

        # make sure we don't actually hit facebook
        data = JSON.stringify
          one: 1
          two: 2

        stub = @stubCatchallSimpleGet 200, data,
          "Content-Type": "application/json"

        requestOptions =
          path: "/cock.bastard?api_key=1234"
          host: "facebook.api.localhost"

        @stubDns { "facebook.api.localhost": "127.0.0.1" }
        @GET requestOptions, ( err, response ) =>
          @ok stub.calledOnce

          @ok not err
          @equal response.contentType, "application/json"

          @ok response.headers[ "x-apiaxleproxy-qps-left" ]
          @ok response.headers[ "x-apiaxleproxy-qpd-left" ]

          response.parseJson ( err, json ) =>
            @ok not err
            @equal json.one, 1

            done 9

  "test GET with apiaxle_key, rather than api_key": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "json"

    # we create the API
    @fixtures.createApi "facebook", apiOptions, ( err ) =>
      @ok not err

      keyOptions =
        forApis: [ "facebook" ]

      @app.model( "keyfactory" ).create "1234", keyOptions, ( err ) =>
        @ok not err

        # make sure we don't actually hit facebook
        data = JSON.stringify
          one: 1

        @stubCatchallSimpleGet 200, data,
          "Content-Type": "application/json"

        requestOptions =
          path: "/cock.bastard?apiaxle_key=1234&api_key=5678"
          host: "facebook.api.localhost"

        @stubDns { "facebook.api.localhost": "127.0.0.1" }
        @GET requestOptions, ( err, response ) =>
          @ok not err

          response.parseJson ( err, json ) =>
            @ok not err
            @equal json.one, 1

            done 5

  "test GET with regex key": ( done ) ->
    apiOptions =
      endPoint:        "graph.facebook.com"
      apiFormat:       "json"
      extractKeyRegex: "/bastard/([A-Za-z0-9]*)/"

    # we create the API
    @fixtures.createApi "facebook", apiOptions, ( err ) =>
      @ok not err

      keyOptions =
        forApis: [ "facebook" ]

      @app.model( "keyfactory" ).create "1234", keyOptions, ( err ) =>
        @ok not err

        # make sure we don't actually hit facebook
        data = JSON.stringify
          one: 1

        @stubCatchallSimpleGet 200, data,
          "Content-Type": "application/json"

        requestOptions =
          path: "/bastard/1234/hello/"
          host: "facebook.api.localhost"

        @stubDns { "facebook.api.localhost": "127.0.0.1" }
        @GET requestOptions, ( err, response ) =>
          @ok not err

          response.parseJson ( err, json ) =>
            @ok not err
            @equal json.one, 1

            done 5

  "test DELETE": ( done ) ->
    @stubDns { "facebook.api.localhost": "127.0.0.1" }

    options =
      path: "/"
      host: "facebook.api.localhost"

    @stubCatchallSimpleDelete 200, "{}",
      "Content-Type": "application/json"

    @DELETE options, ( err, response ) =>
      @ok not err
      @equal options.method, "DELETE"

      done 2

  "test XML error": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "xml"

    @fixtures.createApi "facebook", apiOptions, ( err ) =>
      @ok not err

      @stubDns { "facebook.api.localhost": "127.0.0.1" }

      @GET { path: "/", host: "facebook.api.localhost" }, ( err, response ) =>
        @ok not err

        @match response.headers[ "content-type" ], /application\/xml/

        response.parseXml ( err, xmlDoc ) =>
          @ok not err
          @ok xmlDoc.get "/error"
          @ok xmlDoc.get "/error/type[text()='KeyError']"
          @ok xmlDoc.get "/error/message[text()='No api_key specified.']"

          done 7
