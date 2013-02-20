{ Command } = require "../command"

class exports.Api extends Command
  @modelName = "apiFactory"

  delete: ( id, commnads, keypairs, cb ) =>
    options =
      path: "/v1/api/#{ id }"
    @callApi "DELETE", options, cb

  update: ( id, commnads, keypairs, cb ) =>
    options =
      path: "/v1/api/#{ id }"
      data: JSON.stringify( keypairs )
    @callApi "PUT", options, cb

  create: ( id, commnads, keypairs, cb ) =>
    options =
      path: "/v1/api/#{ id }"
      data: JSON.stringify( keypairs )
    @callApi "POST", options, cb

  show: ( id, commnads, keypairs, cb ) =>
    @callApi "GET", path: "/v1/api/#{ id }", cb
