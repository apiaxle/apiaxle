fs  = require "fs"
sys = require "sys"

{ spawn } = require "child_process"

exports.gitCommand = ( args, cb ) ->
  git = spawn "git", args

  git.stdout.on "data", ( b ) -> console.log( b.toString "utf-8" )
  git.stderr.on "data", ( b ) -> console.error( b.toString "utf-8" )

  git.on "exit", ( code, signal ) ->
    if code isnt 0
      console.error "#{ args.join ' ' } failed, exiting with #{ code }\n"
      process.exit code

    return cb code, signal

exports.getPackages = ( projects, cb ) ->
  packages = { }

  for project in projects
    filename = "#{project}/package.json"

    do ( project ) ->
      data = fs.readFileSync filename, "utf-8"
      packages[ project ] = JSON.parse data

  cb null, packages
