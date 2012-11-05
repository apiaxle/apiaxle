#!/usr/bin/env coffee

fs    = require "fs"
sys   = require "sys"
async = require "async"

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

gitCommand = ( args, cb ) ->
  git = spawn "git", args

  git.stdout.on "data", sys.print
  git.stderr.on "data", process.stderr.write

  git.on "exit", ( code, signal ) ->
    if code isnt 0
      console.error "#{ args.join ' ' } failed, exiting with #{ code }\n"
      process.exit code

    return cb code, signal

process.on "uncaughtException", console.log

projects = [ "api", "base", "proxy" ]
getPackages projects, ( err, packages ) ->
  throw err if err

  all_projects = [ ]

  for pkg_name, pkg_details of packages
    do ( pkg_name, pkg_details ) ->
      old_version = pkg_details.version
      pkg_details.version = new_version

      json = JSON.stringify( pkg_details, null, 2 ) + "\n"
      filename = "#{ pkg_name }/package.json"

      all_projects.push ( cb ) ->
        fs.writeFile filename, json, "utf-8", ( err ) ->
          throw err if err

          gitCommand [ "add", filename ], ( code, signal ) ->
            console.log "#{ pkg_name } was #{ old_version }, becomes #{ new_version }"

            return cb null, filename

  async.series all_projects, ( err, filenames ) ->
    throw err if err

    git_args = [ "commit", "-m", "Version bump (#{ new_version })." ]
    git_args = git_args.concat filenames

    gitCommand git_args, ( ) ->
      gitCommand [ "tag", new_version ], ( ) ->
        console.log( "Tagged as #{ new_version }" )
