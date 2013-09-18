# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
{ Command } = require "../command"

class exports.Apis extends Command
  @modelName = "apifactory"

  help: ( cb ) ->
    return cb null, """Returns a list of APIs. Fieds supported are:

     * from=<int> - count
     * to=<int>
     * resolve=[true|false]"""

  exec: ( commands, keypairs, cb ) ->
    { from, to, resolve } = keypairs
    from = ( encodeURIComponent( parseInt( from ) or 0 ) )
    to = ( encodeURIComponent( parseInt( to ) or 100 ) )
    resolve = if resolve is "true" then "true" else "false"

    @callApi "GET", path: "/v1/apis?resolve=#{ resolve }&to=#{ to }&from=#{ from }", cb
