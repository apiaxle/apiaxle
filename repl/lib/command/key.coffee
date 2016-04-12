# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
{ Command } = require "../command"
querystring = require "querystring"

class exports.Key extends Command
  @modelName = "keyfactory"

  help: ( cb ) ->
    super ( err, help ) =>
      return cb null, help + """\n
        ## Examples:

        To create a Key:

            axle> key "bobskey" create qps=2 qpm=10 qpd=20

        To delete a Key:

            axle> key "twitter" delete

        ## valid options for creation/updating:

        #{ @app.model( @constructor.modelName ).getValidationDocs() }

        See the API documentation for more: http://apiaxle.com/api.html
        """

  delete: ( id, commnads, keypairs, cb ) ->
    options =
      path: "/v1/key/#{ id }"
      data: "{}"

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

  apis: ( id, commands, keypairs, cb ) ->
    resolve = if keypairs.resolve is "true" then "true" else "false"

    options =
      path: "/v1/key/#{ id }/apis?resolve=#{ resolve }"

    @callApi "GET", options, cb

  stats: ( id, commands, keypairs, cb ) ->
    qs = querystring.stringify keypairs
    @callApi "GET", path: "/v1/key/#{ id }/stats?#{ qs }", cb
