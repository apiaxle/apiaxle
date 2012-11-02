#!/usr/bin/env coffee

fs  = require "fs"
sys = require "sys"

{ OptionParser } = require "parseopt"
{ getPackages }  = require "../lib/axle_utils"
{ spawn }        = require "child_process"

parser = new OptionParser
  minargs: 1
  strings:
    arguments: "NEW VERSION"

try
  # get the version we're going to bump to
  [ new_version ] = parser.parse().arguments
catch e
  parser.usage()
  process.exit 1

projects = [ "api", "base", "proxy" ]
getPackages projects, ( err, packages ) ->
  throw err if err

  for pkg_name, pkg_details of packages
    old_version = pkg_details.version
    pkg_details.version = new_version

    json = JSON.stringify( pkg_details, null, 2 ) + "\n"
    filename = "#{ pkg_name }/package.json"

    fs.writeFile filename, json, "utf-8", ( err ) ->
      throw err if err

      console.log "#{ filename }\twas #{ old_version }, becomes #{ new_version }"

      commands = [
        "git add '#{ filename }'"
        "git tag '#{ new_version}'"
        "git ci -m 'Version bumped to #{ new_version }'"
      ]

      command = commands.join(" && ")

      # add and commit
      console.log "Running: #{ command }"
      script = spawn command

      script.stdout.on "data", sys.print
      script.stderr.on "data", sys.print

      script.on "exit", ( code, signal ) ->
        if code isnt 0
          process.exit code

