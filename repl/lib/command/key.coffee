{ Command } = require "../command"

class exports.Key extends Command
  @modelName = "keyFactory"

  help: ( cb ) ->
    super ( err, help ) =>
      return cb null, help + """\n
        ## Examples:

        To create a Key:

            axle> key "bobskey" create qps=2 qpd=20

        To delete a Key:

            axle> key "twitter" delete

        ## valid options for creation/updating:

        #{ @app.model( @constructor.modelName ).getValidationDocs() }

        See the API documentation for more: http://apiaxle.com/api.html
        """

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

  stats: ( id, commands, keypairs, cb ) ->
    @callApi "GET", path: "/v1/key/#{ id }/stats", cb

  apis: ( id, commands, keypairs, cb ) ->
    resolve = if keypairs.resolve is "true" then "true" else "false"
