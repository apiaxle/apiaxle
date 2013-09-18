# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
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

class exports.DNSError extends AppError
  @status = 502

class exports.ConnectionError extends AppError
  @status = 502
