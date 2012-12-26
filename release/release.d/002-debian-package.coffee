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

  execute: ( cb ) ->
    @installModulesInAllProjects cb
