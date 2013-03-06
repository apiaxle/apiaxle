util   = require "util"
fs     = require "fs"
muffin = require "muffin"

{ spawn }  = require "child_process"

jsBuild = ( options, globs ) ->
  muffin.run
    files: globs
    options: options
    map:
      "(.+?).coffee$": ( m ) ->
        muffin.compileScript m[0], "#{m[1]}.js", { bare: true }

jsClean = ( options, globs ) ->
  muffin.run
    files: globs
    options: options
    map:
      "(.+?).js": ( m ) -> fs.unlinkSync "#{m[0]}"

test = ( options ) ->
  script = spawn "./bin/run-tests.bash"

  script.stdout.on "data", util.print
  script.stderr.on "data", util.print
  script.on "exit", ( code, signal ) -> process.exit code

exports.jsBuild = jsBuild
exports.jsClean = jsClean
exports.test = test
