{ Command } = require "../command"

class exports.Info extends Command
  help: ( cb ) ->
    return cb null, "Returns meta information about ApiAxle."

  exec: ( commands, keypairs, cb ) ->
    @callApi "GET", path: "/v1/info", cb
