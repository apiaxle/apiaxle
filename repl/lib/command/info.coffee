{ Command } = require "../command"

class exports.Info extends Command
  @help = "Returns information about ApiAxle."

  exec: ( commands, keypairs, cb ) ->
    @callApi "GET", path: "/v1/info", cb
