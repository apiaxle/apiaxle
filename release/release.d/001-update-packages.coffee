# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
fs = require "fs"
async = require "async"

{ gitCommand } = require "../lib/exec"
{ PluginBase } = require "../lib/plugin_base"

class exports.PackageFileVersionUpdater extends PluginBase
  updateGit: ( filenames, cb ) ->
    # add the files, commit the files and then tag HEAD
    gitCommand [ "add" ].concat( filenames ), @logger, ( err ) =>
      return cb err if err

      commit_args = [ "commit",
                      "-m",
                      "Version bump (#{ @new_version })." ]

      gitCommand commit_args.concat( filenames ), @logger, ( err ) =>
        return cb err if err

        gitCommand [ "tag", @new_version ], @logger, ( err ) =>
          return cb err if err

          @logger.info "Git tag #{ @new_version } applied."
          return cb null, @new_version

  execute: ( cb ) ->
    all_filenames = []

    for project in @projects
      filename = "#{ project }/package.json"
      all_filenames.push filename

      try
        # read the current package
        data = fs.readFileSync filename, "utf-8"
        pkg_details = JSON.parse data

        # update the version to be the new one
        old_version = pkg_details.version
        pkg_details.version = @new_version

        # if any of the projects depend on the *other* projects then
        # update that dependency version too.
        for subproj in @projects
          dep_name = "apiaxle-#{ subproj }"
          if dep_name of pkg_details.dependencies
            pkg_details.dependencies[ dep_name ] = @new_version
            @logger.info "Updating '#{ project }' to use latest '#{ dep_name }'"

        # json it again
        json = JSON.stringify( pkg_details, null, 2 ) + "\n"

        @logger.info "Moving #{ filename } from #{ old_version } to #{ @new_version }."

        # write it back out again
        fs.writeFileSync filename, json, "utf-8"
      catch err
        return cb err, null

    @updateGit all_filenames, cb
