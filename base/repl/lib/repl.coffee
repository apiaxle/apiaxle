_ = require "underscore"
parser = require "./parser"
readline = require "readline"

# command loading
{ Api } = require "./../command/api"
{ Apis } = require "./../command/apis"
{ Keys } = require "./../command/keys"
{ Key } = require "./../command/key"

class exports.ReplHelper
  @all_commands =
    api: Api
    apis: Apis
    keys: Keys
    key: Key

  @help = """Available commands are: #{ _.keys( @all_commands ).join ', ' }
             Try the one of the commands with no arguments for more
             information."""

  constructor: ( @app ) ->

  initReadline: ( onCloseCb ) ->
    @rl = readline.createInterface
      input: process.stdin
      output: process.stdout

    @rl.on "close", onCloseCb

  runCommands: ( [ commands, keypairs ], cb ) ->
    # get the initial highlevel command
    command = commands.shift()

    # quit/exit are slightly magic
    return if command in [ "quit", "exit" ]
    return cb null, @constructor.help if command is "help"

    if not @constructor.all_commands[ command ]?
      return cb new Error "I don't know about '#{ command }'. Try 'help' instead."

    # init the class
    command_object = new @constructor.all_commands[ command ]( @app )

    # run the method
    command_object.exec commands, keypairs, cb

  topLevelInput: ( err, info ) =>
    console.log "Error: #{ err.message }" if err
    console.log info if info

    @rl.question "axle> ", ( entry ) =>
      return @topLevelInput() if /^\s*$/.exec entry

      all = parser entry

      @runCommands all, @topLevelInput
