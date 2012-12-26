fs   = require "fs"

module.exports = ( env, cb ) ->
  possible_locations = [
    "config/#{env}.json",
    "/etc/apiaxle/#{env}.json"
  ]

  for filename in possible_locations
    if fs.existsSync filename
      try
        output = JSON.parse fs.readFileSync( filename ), "utf8"
        return cb null, output
      catch e
        return cb new Error "Problem parsing #{filename}: #{e}"

  # try to be somewhat helpful
  err = "No configuration file could be loaded. "
  err += "Looked in #{ possible_locations.join ', ' }"

  return cb new Error err
