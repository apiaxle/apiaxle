util       = require "util"
fs         = require "fs"
muffin     = require "muffin"
coffeelint = require "coffeelint"
colors     = require "colors"

{ spawn }  = require "child_process"

lint_config = require "../../coffeelint.json"

lint = ( options, globs ) ->
  colors.setTheme
    warn: "yellow"
    error: "red"

  muffin.run
    files: globs
    options: options
    map:
      "(.+?).coffee$": ( [ filename ] ) ->
        exit_code = 0

        input = fs.readFileSync( filename, "utf-8" )
        output = coffeelint.lint( input, lint_config )

        if output.length > 0
          for line in output
            { lineNumber, rule, message, level } = line
            console.log "#{ filename }:#{ lineNumber }: #{ rule } - #{ message }"[ level ]
            exit_code = 1 if level is "error"

        process.exit exit_code

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
      "(.+?).js": ( m ) ->
        console.log( "Unlinking #{m[0]}" )
        fs.unlinkSync "#{m[0]}"

run = ( command, args ) ->
  script = spawn command, args

  script.stdout.on "data", util.print
  script.stderr.on "data", util.print
  script.on "exit", ( code, signal ) -> process.exit code

fixHashbang = ( options, file ) ->
  run "sed", [ "-i", "1i\#!/usr/bin/env node", file ]

test = ( options ) ->
  run "./bin/run-tests.bash"

exports.jsBuild = jsBuild
exports.jsClean = jsClean
exports.test = test
exports.fixHashbang = fixHashbang
exports.lint = lint
