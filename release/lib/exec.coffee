{ spawn } = require "child_process"

exports.exec = ( command, args, cb ) ->
  toExec = spawn command, args

  toExec.stdout.on "data", ( b ) ->
    console.log( b.toString "utf-8" )

  toExec.stderr.on "data", ( b ) ->
    process.stderr.write "#{ b.toString( "utf-8" ) }\n"

  toExec.on "exit", ( code, signal ) ->
    if code isnt 0
      err = new Error "#{ args.join ' ' } failed, exiting with #{ code }"
      return cb err, null, null

    return cb null, code, signal

# run a git command
exports.gitCommand = ( args, cb ) ->
  exports.exec "git", args, cb
