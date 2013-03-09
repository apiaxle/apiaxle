{ Command } = require "../command"

class exports.Key extends Command
  @modelName = "keyFactory"

  delete: ( id, commnads, keypairs, cb ) ->
    options =
      path: "/v1/key/#{ id }"
    @callApi "DELETE", options, cb

  update: ( id, commnads, keypairs, cb ) ->
    options =
      path: "/v1/key/#{ id }"
      data: JSON.stringify( keypairs )
    @callApi "PUT", options, cb

  create: ( id, commnads, keypairs, cb ) ->
    options =
      path: "/v1/key/#{ id }"
      data: JSON.stringify( keypairs )
    @callApi "POST", options, cb

  show: ( id, commnads, keypairs, cb ) ->
    @callApi "GET", path: "/v1/key/#{ id }", cb
