_ = require "underscore"
{ ModelCommand } = require "../command"

class exports.Key extends ModelCommand
  @modelName = "keyFactory"

  help: ( commands, cb ) ->
    help = "key [find|update|delete] <id>\n\n"
    help += "key create <id> endPoint=<endpoint>:\nFields supported:\n"
    help += @model().getValidationDocs()

    return cb null, help
