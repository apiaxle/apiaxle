# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
{ ApiaxleController } = require "../controller"

class exports.DocsModel extends ApiaxleController
  @verb = "get"

  path: -> "/v1/docs/models"

  execute: ( req, res, next ) ->
    all = {}

    for model, details of @app.plugins.models
      if docs = details.constructor.structure
        all[model] = docs

    res.json all

class exports.DocsControllers extends ApiaxleController
  @verb = "get"

  path: -> "/v1/docs/controllers"

  execute: ( req, res, next ) ->
    all = {}

    for controller, details of @app.plugins.controllers
      console.log( details )

      if docs = details.docs?()
        all[controller] = docs
        all[controller].path = details.path()

    res.json all
