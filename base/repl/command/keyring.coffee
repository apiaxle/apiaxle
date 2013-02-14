_ = require "underscore"
{ ModelCommand } = require "../command"

class exports.KeyRing extends ModelCommand
  @modelName = "keyringFactory"

  help: ( commands, cb ) ->
    help = "keyring [find|update|delete] <id>\n\n"
    help += "keyring create <id>\nFields supported:\n"
    help += @model().getValidationDocs()

    return cb null, help
