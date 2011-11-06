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

      done 26

  "test POST,GET,PUT and DELETE with unregistered domain": ( done ) ->
    all = [ ]

    for method in [ "POST", "GET", "PUT", "DELETE" ]
      do ( method ) =>
        all.push ( cb ) =>
          options =
            host: "twitter.localhost"
            method: method
            path: "/"
            data: "something"

          @httpRequest options, ( err, response ) =>
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
