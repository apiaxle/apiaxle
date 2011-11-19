async = require "async"

{ GatekeeperTest } = require "../../gatekeeper"

class exports.CatchallTest extends GatekeeperTest
  @start_webserver = true

  "test POST,GET,PUT and DELETE with no subdomain": ( done ) ->
    all = [ ]

    for method in [ "POST", "GET", "PUT", "DELETE" ]
      do ( method ) =>
        all.push ( cb ) =>
          @httpRequest { method: method, path: "/", data: "something" }, ( err, response ) =>
            @isNull err
            @ok response
            @equal response.statusCode, 404

            response.parseJson ( json ) =>
              @ok json.error
              @equal json.error.type, "ApiUnknown"
              @equal json.error.status, "404"

              cb()

    async.parallel all, ( err, results ) =>
      @isUndefined err
      @equal results.length, 4

      done 22

  # TODO: http socket hangup, why?
  # "test POST,GET,PUT and DELETE with unregistered domain": ( done ) ->
  #   all = [ ]

  #   for method in [ "POST" , "GET", "PUT", "DELETE" ]
  #     do ( method ) =>
  #       all.push ( cb ) =>
  #         options =
  #           host: "twitter.api.localhost"
  #           method: method
  #           path: "/"
  #           data: "something"

  #         @httpRequest options, ( err, response ) =>
  #           console.log( options )

  #           @isNull err
  #           @ok response
  #           @equal response.statusCode, 404

  #           response.parseJson ( json ) =>
  #             @ok json.error
  #             @equal json.error.type, "ApiUnknown"
  #             @equal json.error.status, "404"

  #             cb()

  #   async.parallel all, ( err, results ) =>
  #     @isUndefined err
  #     @equal results.length, 4

  #     done 26

  "test GET with registered domain but no key": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "json"

    # we create the API
    @application.model( "api" ).create "facebook", apiOptions, ( err ) =>
      @isNull err

      @GET { path: "/", host: "facebook.api.localhost" }, ( err, response ) =>
        response.parseJson ( json ) =>
          @ok err = json.error
          @equal err.type, "ApiKeyError"
          @equal err.status, 403

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
          @ok err = json.error
          @equal err.type, "ApiKeyError"
          @equal err.status, 403

          done 4

  "test GET with registered domain and valid key": ( done ) ->
    apiOptions =
      endPoint: "graph.facebook.com"
      apiFormat: "json"

    # we create the API
    @application.model( "api" ).create "facebook", apiOptions, ( err ) =>
      @isNull err

      keyOptions =
        forApi: "facebook"

      @application.model( "apiKey" ).create "1234", keyOptions, ( err ) =>
        @isNull err

        # make sure we don't actually hit facebook
        data = JSON.stringify
          one: 1
          two: 2

        @stubCatchall 200, data,
          "Content-Type": "application/json"

        requestOptions =
          path: "/cock.bastard?api_key=1234"
          host: "facebook.api.localhost"

        @GET requestOptions, ( err, response ) =>
          @isNull err
          @equal response.contentType, "application/json"

          @ok response.headers[ "x-gatekeeperproxy-qps-left" ]
          @ok response.headers[ "x-gatekeeperproxy-qpd-left" ]

          response.parseJson ( json ) =>
            @equal json.one, 1

            done 7
