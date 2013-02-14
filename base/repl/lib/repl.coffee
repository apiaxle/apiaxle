_ = require "underscore"
parser = require "./parser"
readline = require "readline"

# command loading
{ Api } = require "./../command/api"
{ Key } = require "./../command/key"
{ KeyRing } = require "./../command/keyring"

class exports.ReplHelper
  @all_commands =
    api: Api
    key: Key
    keyring: KeyRing

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

    # ugh, help is magic too
    if command is "help"
      available_commands = _.keys( @constructor.all_commands ).join ", "
      help = "Available commands are #{ available_commands }. Try one with "
      help += "help following it. E.G. 'api help'"

      return cb null, help

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
      return @topLevelInput() if /^\s*$/.exec entry

      entered_commands = parser entry

      @runCommands entered_commands, @topLevelInput
