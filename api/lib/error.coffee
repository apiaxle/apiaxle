{ AppError } = require "apiaxle-base"

class exports.NotFoundError extends AppError
  @status = 404

class exports.KeyNotFoundError extends exports.NotFoundError

class exports.ApiNotFoundError extends exports.NotFoundError

class exports.KeyringNotFoundError extends exports.NotFoundError

class exports.AlreadyExists extends AppError
  @status = 400

class exports.InvalidDateFormat extends AppError
  @status = 400

class exports.InvalidContentType extends AppError
  @status = 400
