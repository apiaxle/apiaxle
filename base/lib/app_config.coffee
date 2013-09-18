# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
fs   = require "fs"

module.exports = ( env ) ->
  filenames = [
    "/etc/apiaxle/#{env}.json",
    "#{ process.env.HOME }/.apiaxle/#{ env }.json"
    "config/#{env}.json"
  ]

  for filename in filenames
    if fs.existsSync filename
      try
        return [ filename, JSON.parse( fs.readFileSync( filename ), "utf8" ) ]
      catch e
        throw new Error "Problem parsing #{filename}: #{e}"

  # no configuration found
  return [ null, {} ]
