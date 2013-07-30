# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
{ AppError } = require "apiaxle-base"

class exports.NotFoundError extends AppError
  @status = 404

class exports.KeyNotFoundError extends exports.NotFoundError

class exports.ApiNotFoundError extends exports.NotFoundError

class exports.KeyringNotFoundError extends exports.NotFoundError

class exports.InvalidGranularityType extends AppError
  @status = 400

class exports.AlreadyExists extends AppError
  @status = 400

class exports.InvalidDateFormat extends AppError
  @status = 400

class exports.InvalidContentType extends AppError
  @status = 400
