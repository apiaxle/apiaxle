fs   = require "fs"
path = require "path"

module.exports = ( env ) ->
  filename = "config/#{env}.json"

  if not path.existsSync filename
    return {}

  try
    JSON.parse( fs.readFileSync filename, "utf8" )
  catch e
    throw new Error "Problem parsing #{filename}: #{e}"
