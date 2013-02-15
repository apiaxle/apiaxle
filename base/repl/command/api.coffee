_ = require "underscore"
{ ModelCommand } = require "../command"

class exports.Api extends ModelCommand
  @modelName = "apiFactory"

  addKey: ( commands, cb ) ->
    @_getIdAndObject commands, ( err, dbApi ) =>
      dbApi.addKey commands.shift(), cb

  help: ( commands, cb ) ->
    help = "api [find|update|delete] <api_id>\n\n"
    help += "api addKey <api_id> <key_id>"
    help += "api create <api_id> endPoint=<endpoint>:\nFields supported:\n"
    help += @model().getValidationDocs()

    return cb null, help
