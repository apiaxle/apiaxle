fs   = require "fs"

module.exports = ( env ) ->
  filename = "config/#{env}.json"

  if not fs.existsSync filename
    return {}

  try
    JSON.parse fs.readFileSync( filename ), "utf8"
  catch e
    throw new Error "Problem parsing #{filename}: #{e}"
