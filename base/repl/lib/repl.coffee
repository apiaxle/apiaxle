parser = require "./parser"
readline = require "readline"

# command loading
{ Api } = require "./../command/api"
{ Key } = require "./../command/key"

class exports.ReplHelper
  @all_commands =
    api: Api
    key: Key

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

    # the command exists, is there a method for it though?
    method = ( entered_commands.shift() or "help" )
    if not command_object[ method ]?
      return cb new Error "'#{ command }' doesn't have a '#{ method }' method."

    # run the method
    command_object[ method ]( entered_commands, cb )

  topLevelInput: ( err, info ) =>
    console.error err.message if err
    console.log info if info

    @rl.question "axle> ", ( entry ) =>
      console.error err if err

      entered_commands = parser entry

      @runCommands entered_commands, @topLevelInput
