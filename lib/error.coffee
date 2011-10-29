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

  constructor: ( msg, @options ) ->
    super
    @message = "Queries per second exceeded: #{ msg }"

class exports.QpdExceededError extends exports.GatekeeperError
  @status = 429

  constructor: ( msg, @options ) ->
    super
    @message = "Queries per day exceeded: #{ msg }"

class exports.ApiUnknown extends exports.GatekeeperError
  @status = 404

class exports.ApiKeyError extends exports.GatekeeperError
  @status = 403

class exports.TimeoutError extends exports.GatekeeperError
  @status = 504