# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
{ ApiaxleController } = require "../controller"

class exports.ApisCharts extends ApiaxleController
  @verb = "get"

  path: -> "/v1/docs/models"

  execute: ( req, res, next ) ->
    all = {}

    for model, details of @app.plugins.models
      if docs = details.constructor.structure
        all[model] = docs

    res.json all
