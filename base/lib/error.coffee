# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
class exports.AppError extends Error
  @status = 400

  constructor: ( msg, @options ) ->
    @name = @constructor.name
    @message = msg

    @details = @options?.details

    Error.captureStackTrace @, arguments.callee

class exports.NotFoundError extends exports.AppError
  @status = 404

class exports.KeyNotFoundError extends exports.NotFoundError

class exports.ValidationError extends exports.AppError

class exports.QpsExceededError extends exports.AppError
  @status = 429

  constructor: ( msg, @options ) ->
    super
    @message = "Queries per second exceeded: #{ msg }"

class exports.QpmExceededError extends exports.AppError
  @status = 429

  constructor: ( msg, @options ) ->
    super
    @message = "Queries per minute exceeded: #{ msg }"

class exports.QpdExceededError extends exports.AppError
  @status = 429

  constructor: ( msg, @options ) ->
    super
    @message = "Queries per day exceeded: #{ msg }"

class exports.RedisError extends exports.AppError
  @status = 500
