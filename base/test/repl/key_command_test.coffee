async = require "async"

{ ValidationError } = require "../../lib/error"
{ FakeAppTest } = require "../apiaxle_base"

{ ReplHelper } = require "../../repl/lib/repl"

class exports.KeyCommandTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup repl helper": ( done ) ->
    @repl = new ReplHelper @app

    done()

  "setup an api": ( done ) ->
    fixture =
      api:
        facebook: {}

    @fixtures.create fixture, done

  "test creating a key": ( done ) ->
    command = [ "key", "create", "phil", { forApis: 'facebook' } ]

    @repl.runCommands command, ( err, info ) =>
      @isUndefined err?.message
      @ok info

      done 1
