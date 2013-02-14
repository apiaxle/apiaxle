async = require "async"

{ ValidationError } = require "../../lib/error"
{ FakeAppTest } = require "../apiaxle_base"

{ ReplHelper } = require "../../repl/lib/repl"

class exports.ApiTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup repl helper": ( done ) ->
    @repl = new ReplHelper @app

    done()

  "test creating an API works": ( done ) ->
    commands = [ "api", "create", "facebook", { endPoint: "graph" } ]
    @repl.runCommands commands, ( err, info ) =>
      @isNull err
      @ok info

      @app.model( "apiFactory" ).find "facebook", ( err, dbApi ) =>
        @isNull err
        @ok dbApi

        @equal dbApi.data.endPoint, "graph"
        @equal dbApi.id, "facebook"

        done 6

  "test api with invalid arguments": ( done ) ->
    @repl.runCommands [ "api", "create", "facebook", { "blah": "1" } ], ( err, info ) =>
      @equal err.message, "I can't handle the field 'blah'"

      done 1

  "test api with missing arguments": ( done ) ->
    @repl.runCommands [ "api", "create", "facebook" ], ( err, info ) =>
      @equal err.message, "Missing required values: 'endPoint'"

      done 1

  "test api with no arguments": ( done ) ->
    @repl.runCommands [ "api" ], ( err, info ) =>
      @equal err.message, "'api' doesn't have a 'help' method."

      done 1
