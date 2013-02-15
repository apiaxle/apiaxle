_ = require "underscore"
{ ModelCommand } = require "../command"

class exports.Api extends ModelCommand
  @modelName = "apiFactory"

  addKey: ( commands, cb ) ->
    @_getIdAndObject commands, ( err, dbApi ) =>
      dbApi.addKey commands.shift(), cb

  help: ( commands, cb ) ->
    help = "api [find|update|delete] <id>\n\n"
    help += "api create <id> endPoint=<endpoint>:\nFields supported:\n"
    help += @model().getValidationDocs()

    return cb null, help
