_ = require "underscore"

{ ApiaxleController } = require "../controller"
{ AlreadyExists } = require "../../../lib/error"

class exports.CreateApi extends ApiaxleController
  @verb = "post"

  docs: ->
    """Add a new API definition for `:api`.

    ### Fields supported:

    #{ @app.model( 'api' ).getValidationDocs() }

    ### Returns:

    * The inserted structure (including the new timestamp fields).
    """

  middleware: -> [ @mwContentTypeRequired(), @mwApiDetails( ) ]

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

  middleware: -> [ @mwApiDetailsRequired( @app ) ]

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

  middleware: -> [ @mwApiDetailsRequired( @app ) ]

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

  middleware: -> [ @mwContentTypeRequired( ), @mwApiDetailsRequired( @app ) ]

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

class exports.ListApiKeys extends ApiaxleController
  @verb = "get"

  path: -> "/v1/api/:api/keys/:from/:to"

  docs: ->
    """List keys belonging to :api

    ### Path parameters

    * from: Integer for the index of the first key you want to
      see. Starts at zero.
    * to: Integer for the index of the last key you want to
      see. Starts at zero.

    ### Supported query params:

    * resolve: if set to `true` then the details concerning the listed
      keys will also be printed. Be aware that this will come with a
      minor performace hit.

    ### Returns:

    * Without `resolve` the result will be an array with one key per
      entry.
    * If `resolve` is passed then results will be an object with the
      key name as the key and the details as the value.
    """

  modelName: -> "api"

  middleware: -> [ @mwApiDetails( @app ) ]

  execute: ( req, res, next ) ->
    @app.model( "api" ).get_keys req.params.api, req.params.from, req.params.to, ( err, results ) =>
      return next err if err

      if not req.query.resolve?
        return res.json results

      @resolve @app.model("key"), results, (err, resolved_results) ->
        return next err if err
        return res.json resolved_results
