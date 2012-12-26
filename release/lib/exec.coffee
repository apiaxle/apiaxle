{ spawn } = require "child_process"

exports.exec = ( command, args, logger, cb ) ->
  cwd = process.cwd()
  cmd = "#{ command } #{ args.join ' ' }"
  logger.debug "Running '#{ cmd }' in '#{ cwd }'"

  toExec = spawn command, args

  stdout = ""
  stderr = ""
  toExec.stdout.on "data", ( b ) -> stdout +=  b.toString( "utf-8" )
  toExec.stderr.on "data", ( b ) -> stderr += "#{ b.toString( "utf-8" ) }"

  toExec.on "exit", ( code, signal ) ->
    if code isnt 0
      err = new Error "#{ args.join ' ' } failed, exiting with #{ code }"
      logger.fatal err

      all_output =
        stderr: stderr.split "\n"
        stdout: stdout.split "\n"

      for name, output of all_output
        for line in output
          logger.info "#{ name }: #{ line }"

      return cb err, null, null

    return cb null, code, signal

# run a git command
exports.gitCommand = ( args... ) -> exports.exec "git", args...
