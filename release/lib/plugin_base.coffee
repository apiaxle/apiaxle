{ StdoutLogger } = require "../../base/lib/stderrlogger"

class exports.PluginBase
  constructor: ( @logger, @new_version, @projects ) ->

  getArguments: ( parser ) ->
