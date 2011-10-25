class exports.Redis
  constructor: ( @gatekeeper ) ->
    env = @gatekeeper.constructor.env
    name = @constructor.name.toLowerCase()

    @ns = "gatekeeper:#{ env }:#{ name }:"
