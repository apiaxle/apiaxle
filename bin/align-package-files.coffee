#!/usr/bin/env coffee

fs = require "fs"
_  = require "underscore"

projects = [ "api", "base", "proxy" ]

getPackages = ( cb ) ->
  packages = { }

  for project in projects
    filename = "#{project}/package.json"

    do ( project ) ->
      data = fs.readFileSync filename, "utf-8"
      packages[ project ] = JSON.parse data

  cb null, packages

getVersions = ( packages, cb ) ->
  vers = [ ]

  for project, pkg of packages
    vers.push pkg.version

  cb null, _.uniq vers.sort()

getPackages ( err, packages ) ->
  throw new Error err if err

  getVersions packages, ( err, versions ) ->
    if versions.length > 1
      console.log( "Version mismatch: ", versions )
