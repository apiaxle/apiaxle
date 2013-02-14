{ TwerpTest } = require "twerp"
{ runCommands } = require "../../repl/apiaxle"

class exports.TestApiCommand extends TwerpTest
  "test API creation errors": ( done ) ->
    runCommands [ "api" ], ( err, info ) =>
      @ok err

      done()
