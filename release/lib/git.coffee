{ spawn } = require "child_process"

# run a git command
exports.gitCommand = ( args, cb ) ->
  git = spawn "git", args

  git.stdout.on "data", ( b ) -> console.log( b.toString "utf-8" )
  git.stderr.on "data", ( b ) -> console.error( b.toString "utf-8" )

  git.on "exit", ( code, signal ) ->
    if code isnt 0
      err = new Error "#{ args.join ' ' } failed, exiting with #{ code }"
      return cb err, null, null

    return cb null, code, signal
