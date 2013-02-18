_ = require "underscore"
parser = require "./parser"
readline = require "readline"

# command loading
{ Api } = require "./../command/api"

class exports.ReplHelper
  @all_commands =
    api: Api

  constructor: ( @app ) ->

  initReadline: ( onCloseCb ) ->
    @rl = readline.createInterface
      input: process.stdin
      output: process.stdout

    @rl.on "close", onCloseCb

  runCommands: ( entered_commands, cb ) ->
    # get the initial highlevel command
    command = entered_commands.shift()

    # quit/exit are slightly magic
    return if command in [ "quit", "exit" ]

    if not @constructor.all_commands[ command ]?
      return cb new Error "I don't know about '#{ command }'. Try 'help' instead."

    # init the class
    command_object = new @constructor.all_commands[ command ]( @app )

    # run the method
    command_object.exec entered_commands, cb

  topLevelInput: ( err, info ) =>
    console.error err.message if err
    console.log info if info

    @rl.question "axle> ", ( entry ) =>
      return @topLevelInput() if /^\s*$/.exec entry

      entered_commands = parser entry

      @runCommands entered_commands, @topLevelInput
