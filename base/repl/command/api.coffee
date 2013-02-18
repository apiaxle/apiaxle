{ ModelCommand } = require "../command"

class exports.Api extends ModelCommand
  @modelName = "apiFactory"

  exec: ( commands, cb ) ->
    @_getIdAndObject commands, ( err, @dbApi ) =>
      return cb err if err

      switch command = commands.shift()
        when "create" then @create commands, cb
        when "show" then @show commands, cb

        # nothing entered
        when null then @show commands, cb
        when undefined then @show commands, cb

  show: ( commands, cb ) =>
    @GET path: "/v1/api/#{ @dbApi.id }", ( err, res ) ->
      return err if err

      res.parseJson ( err, json ) ->
        return cb err if err
        return cb null, json

  create: ( commands, cb ) =>
    cb()
