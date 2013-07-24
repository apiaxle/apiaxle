# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
{ Command } = require "../command"
querystring = require "querystring"

class exports.Keyring extends Command
  @modelName = "keyringfactory"

  help: ( cb ) ->
    super ( err, help ) =>
      return cb null, help + """\n
        ## Examples:

        To create a keyring:

            axle> keyring "container" create

        To delete a keyring:

            axle> keyring "container" delete

        ## valid options for creation/updating:

        #{ @app.model( @constructor.modelName ).getValidationDocs() }

        See the API documentation for more: http://apiaxle.com/api.html
        """

  unlinkkey: ( id, commands, keypairs, cb ) ->
    if not key = commands.shift()
      return cb new Error "Please provide a key name to link to #{ id }."

    options =
      path: "/v1/keyring/#{ id }/unlinkkey/#{ key }"
      data: "{}"

    @callApi "PUT", options, cb

  linkkey: ( id, commands, keypairs, cb ) ->
    if not key = commands.shift()
      return cb new Error "Please provide a key name to link to #{ id }."

    options =
      path: "/v1/keyring/#{ id }/linkkey/#{ key }"
      data: "{}"

    @callApi "PUT", options, cb

  delete: ( id, commands, keypairs, cb ) ->
    options =
      path: "/v1/keyring/#{ id }"
      data: "{}"

    @callApi "DELETE", options, cb

  update: ( id, commands, keypairs, cb ) ->
    options =
      path: "/v1/keyring/#{ id }"
      data: JSON.stringify( keypairs )

    @callApi "PUT", options, cb

  keys: ( id, commands, keypairs, cb ) ->
    { from, to, resolve } = keypairs
    from = ( encodeURIComponent( parseInt( from ) or 0 ) )
    to = ( encodeURIComponent( parseInt( to ) or 100 ) )
    resolve = if resolve is "true" then "true" else "false"

    options =
      path: "/v1/keyring/#{ id }/keys?resolve=#{ resolve }&to=#{ to }&from=#{ from }"

    @callApi "GET", options, cb

  create: ( id, commands, keypairs, cb ) ->
    options =
      path: "/v1/keyring/#{ id }"
      data: JSON.stringify( keypairs )

    @callApi "POST", options, cb

  show: ( id, commands, keypairs, cb ) ->
    @callApi "GET", path: "/v1/keyring/#{ id }", cb

  stats: ( id, commands, keypairs, cb ) ->
    qs = querystring.stringify keypairs
    @callApi "GET", path: "/v1/keyring/#{ id }/stats?#{ qs }", cb
