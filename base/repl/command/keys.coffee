{ Command } = require "../command"

class exports.Keys extends Command
  @modelName = "keyFactory"

  exec: ( commands, keypairs, cb ) ->
    { from, to, resolve } = keypairs
    from = ( encodeURIComponent( parseInt( from ) or 0 ) )
    to = ( encodeURIComponent( parseInt( to ) or 100 ) )
    resolve = if resolve is "true" then "true" else "false"

    @callApi "GET", path: "/v1/keys?resolve=#{ resolve }&to=#{ to }&from=#{ from }", cb
