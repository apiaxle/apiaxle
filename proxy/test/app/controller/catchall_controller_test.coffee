async = require "async"
libxml = require "libxmljs"

{ ApiaxleTest } = require "../../apiaxle"

class exports.CatchallTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "test POST,GET,PUT and DELETE with no subdomain": ( done ) ->
    all = [ ]

    for method in [ "POST", "GET", "PUT", "DELETE" ]
      do ( method ) =>
        all.push ( cb ) =>
          options =
            method: method
            path: "/"
            data: "something"

          @httpRequest options, ( err, response ) =>
            @isNull err
            @ok response
            @equal response.statusCode, 404

            response.parseJson ( json ) =>
              # meta
              @equal json.meta.version, 1
              @equal json.meta.status_code, response.statusCode

              @ok json.results.error
              @equal json.results.error.type, "ApiUnknown"

              cb()

    async.parallel all, ( err, results ) =>
      @isNull err
      @equal results.length, 4

      done 30

  "test POST,GET,PUT and DELETE with unregistered domain": ( done ) ->
    all = [ ]

    for method in [ "POST", "GET", "PUT", "DELETE" ]
      do ( method ) =>
        all.push ( cb ) =>
          options =
            method: method
            hostname: "twitter.api.localhost"
            path: "/?api_key=1234"
            data: "something"

          @httpRequest options, ( err, response ) =>
            if err and err.code is "ENOTFOUND"
              # this usually means missing host entries
              console.log "WARNING: You might need to put facebook.api.localhost" +
                " and twitter.api.localhost into your hosts file."

            @isNull err
            @ok response
            @equal response.statusCode, 404

            response.parseJson ( json ) =>
              @ok json.results.error
              @equal json.results.error.type, "ApiUnknown"

              cb()

    async.series all, ( err, results ) =>
      @isNull err
      @equal results.length, 4

      done 22

  "test GET with registered domain but no key": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "json"

    # we create the API
    @application.model( "api" ).create "facebook", apiOptions, ( err ) =>
      @isNull err

      @GET { path: "/", host: "facebook.api.localhost" }, ( err, response ) =>
        @isNull err

        response.parseJson ( json ) =>
          @ok err = json.results.error
          @equal err.type, "KeyError"

          done 4

  "test GET with registered domain but invalid key": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "json"

    # we create the API
    @application.model( "api" ).create "facebook", apiOptions, ( err ) =>
      @isNull err

      @GET { path: "/?api_key=1", host: "facebook.api.localhost" }, ( err, response ) =>
        response.parseJson ( json ) =>
          @ok err = json.results.error
          @equal err.type, "KeyError"

          done 3

  "test GET with registered domain and valid key": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "json"

    # we create the API
    @application.model( "api" ).create "facebook", apiOptions, ( err ) =>
      @isNull err

      keyOptions =
        forApi: "facebook"

      @application.model( "key" ).create "1234", keyOptions, ( err ) =>
        @isNull err

        # make sure we don't actually hit facebook
        data = JSON.stringify
          one: 1
          two: 2

        stub = @stubCatchall 200, data,
          "Content-Type": "application/json"

        requestOptions =
          path: "/cock.bastard?api_key=1234"
          host: "facebook.api.localhost"

        @GET requestOptions, ( err, response ) =>
          @isNull err
          @equal response.contentType, "application/json"

          @ok response.headers[ "x-apiaxleproxy-qps-left" ]
          @ok response.headers[ "x-apiaxleproxy-qpd-left" ]

          response.parseJson ( json ) =>
            @equal json.one, 1

            done 7

  "test GET with apiaxle_key, rather than api_key": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "json"

    # we create the API
    @application.model( "api" ).create "facebook", apiOptions, ( err ) =>
      @isNull err

      keyOptions =
        forApi: "facebook"

      @application.model( "key" ).create "1234", keyOptions, ( err ) =>
        @isNull err

        # make sure we don't actually hit facebook
        data = JSON.stringify
          one: 1

        @stubCatchall 200, data,
          "Content-Type": "application/json"

        requestOptions =
          path: "/cock.bastard?apiaxle_key=1234&api_key=5678"
          host: "facebook.api.localhost"

        @GET requestOptions, ( err, response ) =>
          @isNull err

          response.parseJson ( json ) =>
            @equal json.one, 1

            done 4

  "test XML error": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "xml"

    @application.model( "api" ).create "facebook", apiOptions, ( err ) =>
      @GET { path: "/", host: "facebook.api.localhost" }, ( err, response ) =>
        @isNull err

        @match response.headers[ "content-type" ], /application\/xml/

        response.parseXml ( xmlDoc ) =>
          @ok xmlDoc.get "/error"
          @ok xmlDoc.get "/error/type[text()='KeyError']"
          @ok xmlDoc.get "/error/message[text()='No api_key specified.']"

          done 5
