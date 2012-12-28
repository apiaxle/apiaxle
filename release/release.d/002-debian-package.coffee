async  = require "async"
rimraf = require "rimraf"

{ exec }       = require "../lib/exec"
{ PluginBase } = require "../lib/plugin_base"

class exports.BuildDebianPackage extends PluginBase
  installModulesInAllProjects: ( cb ) =>
    each_project = []

    for project in @projects
      do( project ) =>
        each_project.push ( cb ) =>
          process.chdir project

          exec "npm", [ "install" ], @logger, ( err ) =>
            return cb err if err

            process.chdir ".."
            return cb null

    async.series each_project, cb

  runDhMake: ( cb ) =>
    dh_args = [ "--email", "support@apiaxle.com",
                "--single",
                "--native",
                "--packagename", "apiaxle_#{ @new_version }" ]

    exec "release/bin/dh_make_wrapper.bash", dh_args, @logger, cb

  deleteDebianDir: ( cb ) =>
    @logger.info "Deleting debian directory"
    rimraf "debian", cb

  runDpkgBuildPackage: ( cb ) =>
    # do the building in /tmp so we don't need root
    process.env[ "DESTDIR" ] = "/tmp"

    # DESTDIR=/tmp dpkg-buildpackage -uc -us
    exec "dpkg-buildpackage", [ "-uc", "-us" ], @logger, cb

  execute: ( cb ) ->
    everything = []

    everything.push @installModulesInAllProjects
    everything.push @deleteDebianDir
    everything.push @runDhMake
    everything.push @runDpkgBuildPackage

    async.series everything, cb
