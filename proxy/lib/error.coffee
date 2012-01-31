{ AppError } = require "apiaxle.base"

class exports.ApiUnknown extends AppError
  @status = 404

class exports.ApiKeyError extends AppError
  @status = 403

class exports.TimeoutError extends AppError
  @status = 504
