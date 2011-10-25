class exports.GatekeeperError extends Error
  @status = 400

  constructor: ( msg, @options ) ->
    @name = arguments.callee.name
    @message = msg

    @details = @options?.details

    Error.captureStackTrace @, arguments.callee

class exports.NotFoundError extends exports.GatekeeperError
  @status = 404

class exports.RedisError extends exports.GatekeeperError
  @status = 500

class exports.QpsExceededError extends exports.GatekeeperError
  @status = 429

class exports.QpdExceededError extends exports.GatekeeperError
  @status = 429
