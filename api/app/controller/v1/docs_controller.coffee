# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
{ ApiaxleController } = require "../controller"

class exports.DocsModel extends ApiaxleController
  @verb = "get"

  path: -> "/v1/docs/models"

  docs: ->
    {}=
      verb: "GET"
      title: "JSON representation of the model docs."
      response: "JSON for each model, including types etc."

  execute: ( req, res, next ) ->
    all = {}

    for model, details of @app.plugins.models
      if docs = details.constructor.structure
        all[model] = docs

    @json res, all

class exports.DocsControllers extends ApiaxleController
  @verb = "get"

  path: -> "/v1/docs/controllers"

  docs: ->
    {}=
      verb: "GET"
      title: "JSON representation of the controller docs."
      response: "JSON for each controller."

  execute: ( req, res, next ) ->
    all = {}

    for controller, details of @app.plugins.controllers
      if docs = details.docs?()
        all[controller] = docs
        all[controller].path = details.path()

    @json res, all
