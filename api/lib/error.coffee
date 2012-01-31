{ AppError } = require "apiaxle.base"

class exports.NotFoundError extends AppError
  @status = 404

class exports.AlreadyExists extends AppError
  @status = 400

class exports.InvalidDateFormat extends AppError
  @status = 400
