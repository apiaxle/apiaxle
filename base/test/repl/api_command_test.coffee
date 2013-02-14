async = require "async"

{ ValidationError } = require "../../lib/error"
{ FakeAppTest } = require "../apiaxle_base"

{ ReplHelper } = require "../../repl/lib/repl"

class exports.ApiTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup repl helper": ( done ) ->
    @repl = new ReplHelper @app

    done()

  "test updating a non-existant API": ( done ) ->
    commands = [
      "api",
      "update",
      "facebook",
      { endPoint: "graph", protocol: "https" } ]

    @repl.runCommands commands, ( err, info ) =>
      @ok err
      @isUndefined info

      @equal err.message, "'facebook' doesn't exist."

      done 3

  "test updating an API": ( done ) ->
    fixture =
      api:
        facebook: {}

    commands = [
      "api",
      "update",
      "facebook",
      { endPoint: "graph", protocol: "https" } ]

    @fixtures.create fixture, ( err ) =>
      @isNull err

      @repl.runCommands commands, ( err, info ) =>
        @isNull err
        @ok info

        @equal info.protocol, "https"

        done 4

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
