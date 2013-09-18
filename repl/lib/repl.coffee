# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
_ = require "lodash"
util = require "util"
parser = require "./parser"
readline = require "readline"

# command loading
{ Api } = require "./command/api"
{ Keyring } = require "./command/keyring"
{ Keyrings } = require "./command/keyrings"
{ Info } = require "./command/info"
{ Apis } = require "./command/apis"
{ Keys } = require "./command/keys"
{ Key } = require "./command/key"

class exports.ReplHelper
  @all_commands =
    api: Api
    keyring: Keyring
    keyrings: Keyrings
    apis: Apis
    keys: Keys
    key: Key
    info: Info

  help: ->
    """
    Available commands are: #{ _.keys( @constructor.all_commands ).join ', ' }

    For specific help on a command try 'help <command>'.
    """

  constructor: ( @app ) ->

  initReadline: ( onCloseCb ) ->
    @rl = readline.createInterface
      input: process.stdin
      output: process.stdout

    @rl.on "close", onCloseCb

  registrationMaybe: ( cb ) ->
    reg = @app.model "register"

    reg.isRegistered ( err, registered ) =>
      return cb err if err
      return cb null if registered

      # tell the user what's happening
      msg = [ "Thanks for using ApiAxle." ]
      msg.push "Please register with us. We will only do this once"
      msg.push "and promise not to spam you or give your name/email address"
      msg.push "to anyone else."

      console.log( "\n#{ msg.join( ' ' ) }\n" )

      ask = ( cb ) =>
        @rl.question "your email> ", ( email ) =>
          @rl.question "your name> ", ( name ) =>
            console.log( "Please wait - sending details (over https)..." )
            reg.register email, name, ( err ) =>
              if err?.name is "ValidationError"
                console.error "Please enter a valid email address."
                return ask cb

              return cb err

      ask cb

  runCommands: ( [ commands, keypairs ], cb ) ->
    # get the initial highlevel command
    command = commands.shift()

    # quit/exit are slightly magic
    return if command in [ "quit", "exit" ]

    if command is "help"
      if subcommand = commands.shift()
        # init the class
        command_object = new @constructor.all_commands[ subcommand ]( @app )
        return command_object.help cb

      return cb null, @help()

    if not @constructor.all_commands[ command ]?
      return cb new Error "I don't know about '#{ command }'. Try 'help' instead."

    # init the class
    command_object = new @constructor.all_commands[ command ]( @app )

    # run the method
    command_object.exec commands, keypairs, cb

  handleReturn: ( err, info ) ->
    console.log "Error: #{ err.message }" if err

    if info
      if typeof info is "string"
        console.log info
      else
        console.log util.inspect( info, false, null ) if info

  processLine: ( line, cb ) ->
    return cb() if /^\s*$/.exec line
    details = parser line

    @runCommands details, cb

  topLevelInput: ( err, info ) =>
    @handleReturn err, info

    @rl.question "axle> ", ( entry ) =>
      @processLine entry, @topLevelInput
