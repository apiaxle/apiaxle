{ AppError } = require "apiaxle-base"

class exports.ApiDisabled extends AppError
  @status = 400

class exports.KeyDisabled extends AppError
  @status = 401

class exports.ApiUnknown extends AppError
  @status = 404

class exports.KeyError extends AppError
  @status = 403

class exports.EndpointTimeoutError extends AppError
  @status = 504

class exports.EndpointMissingError extends AppError
  @status = 502
