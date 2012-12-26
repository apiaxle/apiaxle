{ StdoutLogger } = require "../../base/lib/stderrlogger"

class exports.PluginBase
  constructor: ( @new_version, @projects ) ->
    @logger = new StdoutLogger()

  getArguments: ( parser ) ->
