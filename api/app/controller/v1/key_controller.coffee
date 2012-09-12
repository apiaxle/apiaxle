_ = require "underscore"

{ ApiaxleController, ListController, CreateController } = require "../controller"
{ NotFoundError, AlreadyExists } = require "../../../lib/error"

key = ( app ) ->
  ( req, res, next ) ->
    app.model( "apiKey" ).find key, ( err, dbKey ) ->
      return next err if err

      req.key = dbKey

      return next()

keyRequired = ( app ) ->
  ( req, res, next ) ->
    api_key = req.params.key

    app.model( "apiKey" ).find api_key, ( err, dbKey ) ->
      return next err if err

      if not dbKey?
        return next new NotFoundError "#{ key } not found."

      req.key = dbKey

      return next()

class exports.ListKeys extends ListController
  @verb = "get"

  path: -> "/v1/key/list/:from/:to"

  docs: ->
    """List the keys in the database.

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

  modelName: -> "apiKey"

class exports.CreateKey extends ApiaxleController
  @verb = "post"

  docs: ->
    """Add a new key.

    ### Fields supported:

    #{ @app.model( 'apiKey' ).getValidationDocs() }

    ### Returns:

    * The newly inseted structure (including the new timestamp
      fields).
    """

  middleware: -> [ key( @app ) ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    # error if it exists
    if req.key?
      return next new AlreadyExists "#{ key } already exists."

    @app.model( "apiKey" ).create req.params.key, req.body, ( err, newObj ) ->
      return next err if err

      res.json newObj

class exports.ViewKey extends ApiaxleController
  @verb = "get"

  docs: ->
    """Get the details of key `:key`.

    ### Returns:

    * The key object (including timestamps).
    """

  middleware: -> [ keyRequired( @app ) ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    res.json req.key

class exports.DeleteKey extends ApiaxleController
  @verb = "delete"

  docs: ->
    """Delete the key `:key`.

    ### Returns:

    * `true` on success.
    """

  middleware: -> [ keyRequired( @app ) ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    model = @app.model "apiKey"

    model.del req.params.key, ( err, newKey ) ->
      return next err if err

      res.json true

class exports.ModifyKey extends ApiaxleController
  @verb = "put"

  docs: ->
    """Update an existing key `:key`. Fields passed in will will be
    merged with the old key details.

    ### Fields supported:

    #{ @app.model( 'apiKey' ).getValidationDocs() }

    ### Returns:

    * The newly inseted structure (including the new timestamp
      fields).
    """

  middleware: -> [ keyRequired( @app ) ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    model = @app.model "apiKey"

    # validate the input
    model.validate req.body, ( err ) =>
      return next err if err

      # modify the key
      _.extend req.key, req.body

      # re-apply it to the db
      model.create req.params.key, req.key, ( err, newKey ) =>
        return next err if err

        res.json newKey
