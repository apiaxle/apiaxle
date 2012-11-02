fs = require "fs"

exports.getPackages = ( projects, cb ) ->
  packages = { }

  for project in projects
    filename = "#{project}/package.json"

    do ( project ) ->
      data = fs.readFileSync filename, "utf-8"
      packages[ project ] = JSON.parse data

  cb null, packages
