# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
class exports.PluginBase
  constructor: ( @logger, @new_version, @projects ) ->

  getArguments: ( parser ) ->
