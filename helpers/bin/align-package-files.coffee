#!/usr/bin/env coffee

_  = require "underscore"
{ getPackages } = require "../lib/axle_utils"

getVersions = ( packages, cb ) ->
  vers = [ ]

  for project, pkg of packages
    vers.push pkg.version

  cb null, _.uniq vers.sort()

projects = [ "api", "base", "proxy" ]
getPackages projects, ( err, packages ) ->
  throw new Error err if err

  getVersions packages, ( err, versions ) ->
    if versions.length > 1
      console.log( "Version mismatch: ", versions )
