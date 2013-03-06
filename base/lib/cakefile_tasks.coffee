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

run = ( command ) ->
  script = spawn command

  script.stdout.on "data", util.print
  script.stderr.on "data", util.print
  script.on "exit", ( code, signal ) -> process.exit code

fixHashbang = ( options, file ) -> run "sed -i '1i\#!/usr/bin/env node' #{file}"
test = ( options ) -> run "./bin/run-tests.bash"

exports.jsBuild = jsBuild
exports.jsClean = jsClean
exports.test = test
exports.fixHashbang = fixHashbang
