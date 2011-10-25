class exports.GatekeeperError extends Error
  constructor: ( msg, @options ) ->
    @name = arguments.callee.name
    @message = msg

    @details = @options?.details

    Error.captureStackTrace @, arguments.callee

class exports.NotFoundError extends exports.GatekeeperError
  constructor: ( msg, @options ) ->
    super
    @jsonStatus = 404
    @htmlStatus = 404

class exports.RedisError extends exports.GatekeeperError
  constructor: ( msg, @options ) ->
    super
    @jsonStatus = 500
