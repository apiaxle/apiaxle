async = require "async"

{ exec }       = require "../lib/exec"
{ PluginBase } = require "../lib/plugin_base"

class exports.BuildDebianPackage extends PluginBase
  installModulesInAllProjects: ( cb ) ->
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

  runDhMake: ( cb ) ->
    dh_args = [ "--email", "support@apiaxle.com",
                "--single",
                "--native",
                "--packagename", "apiaxle_#{ @new_version }" ]

    exec "release/bin/dh_make_wrapper.bash", dh_args, @logger, cb

  execute: ( cb ) ->
    @installModulesInAllProjects ( err ) =>
      return cb err if err

      @runDhMake cb
