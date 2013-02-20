{ Command } = require "../command"

class exports.Api extends Command
  @modelName = "apiFactory"

  addkey: ( id, commands, keypairs, cb ) =>
    if not key = commands.shift()
      return cb new Error "Please provide a key name to add to #{ id }."

    options =
      path: "/v1/api/#{ id }/addkey/#{ key }"
    @callApi "PUT", options, cb

  delete: ( id, commands, keypairs, cb ) =>
    options =
      path: "/v1/api/#{ id }"
    @callApi "DELETE", options, cb

  update: ( id, commands, keypairs, cb ) =>
    options =
      path: "/v1/api/#{ id }"
      data: JSON.stringify( keypairs )
    @callApi "PUT", options, cb

  create: ( id, commands, keypairs, cb ) =>
    options =
      path: "/v1/api/#{ id }"
      data: JSON.stringify( keypairs )
    @callApi "POST", options, cb

  show: ( id, commands, keypairs, cb ) =>
    @callApi "GET", path: "/v1/api/#{ id }", cb
