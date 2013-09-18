# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
{ Command } = require "../command"

class exports.Info extends Command
  help: ( cb ) ->
    return cb null, "Returns meta information about ApiAxle."

  exec: ( commands, keypairs, cb ) ->
    @callApi "GET", path: "/v1/info", cb
