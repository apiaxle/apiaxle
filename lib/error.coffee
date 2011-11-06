{ AppError } = require "gatekeeper.base"

class exports.ApiUnknown extends AppError
  @status = 404
