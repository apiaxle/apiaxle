fun = ( name, args... ) ->
  process.stderr.write name + ": " + args.join( " " ) + "\n"

class exports.StdoutLogger
  debug: ( args... ) -> fun "DEBUG", args
  info: ( args... ) -> fun "INFO", args
  warn: ( args... ) -> fun "WARN", args
  fatal: ( args... ) -> fun "FATAL", args
