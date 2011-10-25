fs = require "fs"

module.exports = walkTreeSync = ( start, dir_callback, file_callback ) ->
  for item in fs.readdirSync( start )
    abs   = "#{start}/#{item}"
    stats = fs.statSync( abs )

    if stats.isDirectory( )
      dir_callback? start, item, stats
      walkTreeSync abs, dir_callback, file_callback
    else if stats.isFile( )
      file_callback? start, item, stats
