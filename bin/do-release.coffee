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
    do ( pkg_name, pkg_details ) ->
      old_version = pkg_details.version
      pkg_details.version = new_version

      json = JSON.stringify( pkg_details, null, 2 ) + "\n"
      filename = "#{ pkg_name }/package.json"

      fs.writeFile filename, json, "utf-8", ( err ) ->
        throw err if err

        commands = [
          [ "git", [ "add", "#{ filename }" ] ],
          [ "git", [ "ci", "-m", "Version bumped to #{ new_version }" ] ],
        ]

        for command in commands
          git = spawn.apply @, command

          git.stdout.on "data", console.log
          git.stderr.on "data", console.log

          git.on "exit", ( code, signal ) ->
            console.log "#{ pkg_name } was #{ old_version }, becomes #{ new_version }"

            process.exit code if code isnt 0
