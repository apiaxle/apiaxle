async = require "async"

{ GatekeeperTest } = require "../../gatekeeper"
{ GetCatchall } = require "../../../app/controller/catchall_controller"

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

      done 26

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
      endpoint: "graph.facebook.com"
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
