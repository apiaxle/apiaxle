_ = require "underscore"

{ ApiaxleController, ListController } = require "../controller"
{ NotFoundError, AlreadyExists } = require "../../../lib/error"

apiDetails = ( app ) ->
  ( req, res, next ) ->
    api = req.params.api

    app.model( "api" ).find api, ( err, dbApi ) ->
      return next err if err

      req.api = dbApi

      return next()

apiDetailsRequired = ( app ) ->
  ( req, res, next ) ->
    api = req.params.api

    app.model( "api" ).find api, ( err, dbApi ) ->
      return next err if err

      if not dbApi?
        return next new NotFoundError "#{ api } not found."

      req.api = dbApi

      return next()

class exports.CreateApi extends ApiaxleController
  @verb = "post"

  docs: ->
    """Add a new API definition for `:api`.

    ### Fields supported:

    #{ @app.model( 'api' ).getValidationDocs() }

    ### Returns:

    * The inserted structure (including the new timestamp fields).
    """

  middleware: -> [ apiDetails( @app ) ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    # error if it exists
    if req.api?
      return next new AlreadyExists "#{ api } already exists."

    @app.model( "api" ).create req.params.api, req.body, ( err, newObj ) ->
      return next err if err

      res.json newObj

class exports.ViewApi extends ApiaxleController
  @verb = "get"

  docs: ->
    """Get the definition for API `:api`.

    ### Returns:

    * The API structure (including the timestamp fields).
    """

  middleware: -> [ apiDetailsRequired( @app ) ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    res.json req.api

class exports.DeleteApi extends ApiaxleController
  @verb = "delete"

  docs: ->
    """Delete the API `:api`.

    ### Returns:

    * `true` on success.
    """

  middleware: -> [ apiDetailsRequired( @app ) ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    model = @app.model "api"

    model.del req.params.api, ( err, newApi ) ->
      return next err if err

      res.json true

class exports.ModifyApi extends ApiaxleController
  @verb = "put"

  docs: ->
    """Update the API `:api`. Will merge fields you pass in.

    ### Fields supported:

    #{ @app.model( 'api' ).getValidationDocs() }

    ### Returns:

    * The merged structure (including the timestamp fields).
    """

  middleware: -> [ apiDetailsRequired( @app ) ]

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

        res.json newApi

class exports.ListApiKeys extends ListController
  @verb = "get"

  docs: ->
    """Add a new API definition for `:api`.

    ### Fields supported:

    #{ @app.model( 'api' ).getValidationDocs() }

    ### Returns:

    * The inserted structure (including the new timestamp fields).
    """

  middleware: -> [ apiDetails( @app ) ]

  path: -> "/v1/api/:api/keys"

  execute: ( req, res, next ) ->
    @app.model( "api" ).get_keys req.params.api, req.body, ( err, newObj ) ->
      return next err if err

      res.json newObj
