{ AppError } = require "app.coffee"

class exports.NotFoundError extends AppError
  @status = 404

class exports.RedisError extends AppError
  @status = 500

class exports.QpsExceededError extends AppError
  @status = 429

  constructor: ( msg, @options ) ->
    super
    @message = "Queries per second exceeded: #{ msg }"

class exports.QpdExceededError extends AppError
  @status = 429

  constructor: ( msg, @options ) ->
    super
    @message = "Queries per day exceeded: #{ msg }"

class exports.ApiUnknown extends AppError
  @status = 404

class exports.ApiKeyError extends AppError
  @status = 403

class exports.TimeoutError extends AppError
  @status = 504

class exports.ValidationError extends AppError
