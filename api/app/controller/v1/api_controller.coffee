_ = require "underscore"

{ ApiaxleController, ListController } = require "../controller"
{ AlreadyExists } = require "../../../lib/error"

class exports.CreateApi extends ApiaxleController
  @verb = "post"

  desc: -> "Provision a new API."

  docs: ->
    """
    ### JSON fields supported

    #{ @app.model( 'api' ).getValidationDocs() }

    ### Returns

    * The inserted structure (including the new timestamp fields).
    """

  middleware: -> [ @mwContentTypeRequired(), @mwApiDetails( ) ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    # error if it exists
    if req.api?
      return next new AlreadyExists "#{ api } already exists."

    @app.model( "api" ).create req.params.api, req.body, ( err, newObj ) =>
      return next err if err

      @json res, newObj

class exports.ViewApi extends ApiaxleController
  @verb = "get"

  desc: -> "Get the definition for an API."

  docs: ->
    """
    ### Returns

    * The API structure (including the timestamp fields).
    """

  middleware: -> [ @mwApiDetails( valid_api_required=true ) ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    @json res, req.api

class exports.DeleteApi extends ApiaxleController
  @verb = "delete"

  desc: -> "Delete an API."

  docs: ->
    """
    ### Returns

    * `true` on success.
    """

  middleware: -> [ @mwApiDetails( valid_api_required=true ) ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    model = @app.model "api"

    model.del req.params.api, ( err, newApi ) =>
      return next err if err

      @json res, true

class exports.ModifyApi extends ApiaxleController
  @verb = "put"

  desc: -> "Update an API."

  docs: ->
    """Will merge fields you pass in.

    ### JSON fields supported

    #{ @app.model( 'api' ).getValidationDocs() }

    ### Returns

    * The merged structure (including the timestamp fields).
    """

  middleware: -> [
    @mwContentTypeRequired( ),
    @mwApiDetails( valid_api_required=true )
  ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    model = @app.model "api"

    # modify the old api struct
    newData = _.extend req.api, req.body

    # validate it
    model.validate newData, ( err, instance ) =>
      return next err if err

      # re-apply it to the db
      model.create req.params.api, instance, ( err, newApi ) =>
        return next err if err

        @json res, newApi

class exports.ListApis extends ListController
  @verb = "get"

  path: -> "/v1/api/list/:from/:to"

  desc: -> "List all APIs."

  docs: ->
    """
    ### Path parameters

    * from: Integer for the index of the first api you want to
      see. Starts at zero.
    * to: Integer for the index of the last api you want to
      see. Starts at zero.

    ### Supported query params

    * resolve: if set to `true` then the details concerning the listed
      apis  will also be printed. Be aware that this will come with a
      minor performace hit.

    ### Returns

    * Without `resolve` the result will be an array with one api per
      entry.
    * If `resolve` is passed then results will be an object with the
      api name as the api and the details as the value.
    """

  modelName: -> "api"

class exports.ListApiKeys extends ApiaxleController
  @verb = "get"

  path: -> "/v1/api/:api/keys/:from/:to"

  desc: -> "List keys belonging to an API."

  docs: ->
    """
    ### Path parameters

    * from: Integer for the index of the first key you want to
      see. Starts at zero.
    * to: Integer for the index of the last key you want to
      see. Starts at zero.

    ### Supported query params

    * resolve: if set to `true` then the details concerning the listed
      keys will also be printed. Be aware that this will come with a
      minor performace hit.

    ### Returns

    * Without `resolve` the result will be an array with one key per
      entry.
    * If `resolve` is passed then results will be an object with the
      key name as the key and the details as the value.
    """

  modelName: -> "api"

  middleware: -> [ @mwApiDetails( @app ) ]

  execute: ( req, res, next ) ->
    @app.model( "api" ).getKeys req.params.api, req.params.from, req.params.to, ( err, results ) =>
      return next err if err

      if not req.query.resolve?
        return @json res, results

      @resolve @app.model("key"), results, (err, resolved_results) =>
        return next err if err
        return @json res, resolved_results
