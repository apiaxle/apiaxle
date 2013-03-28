util       = require "util"
fs         = require "fs"
muffin     = require "muffin"
coffeelint = require "coffeelint"

{ spawn }  = require "child_process"

lint_config =
  no_tabs:
    level: "error"
  no_trailing_whitespace:
    level: "error"
  max_line_length:
    value: 80
    level: "ignore"
  camel_case_classes:
    level: "error"
  indentation:
    value: 2
    level: "error"
  no_implicit_braces:
    level: "ignore"
  no_trailing_semicolons:
    level: "error"
  no_plusplus:
    level: "ignore"
  no_throwing_strings:
    level: "error"
  cyclomatic_complexity:
    value: 11
  line_endings:
    value: "unix"
    level: "error"
  no_implicit_parens:
    level: "ignore"
  no_stand_alone_at:
    level: "error"

lint = ( options, globs ) ->
  muffin.run
    files: globs
    options: options
    map:
      "(.+?).coffee$": ( [ filename ] ) ->
        input = fs.readFileSync( filename, "utf-8" )
        output = coffeelint.lint( input, lint_config )

        if output.length > 0
          for line in output
            { lineNumber, rule, message, level } = line
            console.log "#{ filename }:#{ lineNumber }: #{ rule } - #{ message }"

          process.exit 1

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
