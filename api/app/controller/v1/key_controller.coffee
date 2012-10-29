_ = require "underscore"

{ ApiaxleController, ListController, CreateController } = require "../controller"
{ NotFoundError, AlreadyExists } = require "../../../lib/error"

class exports.ListKeys extends ListController
  @verb = "get"

  path: -> "/v1/key/list/:from/:to"

  desc: -> "List all of the available keys."

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

  modelName: -> "key"

class exports.CreateKey extends ApiaxleController
  @verb = "post"

  desc: -> "Provision a new key."

  docs: ->
    """
    ### JSON fields supported

    #{ @app.model( 'key' ).getValidationDocs() }

    ### Returns

    * The newly inseted structure (including the new timestamp
      fields).
    """

  middleware: -> [ @mwContentTypeRequired( ), @mwKeyDetails( ) ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    # error if it exists
    if req.key?
      return next new AlreadyExists "#{ key } already exists."

    @app.model( "key" ).create req.params.key, req.body, ( err, newObj ) =>
      return next err if err

      @json res, newObj

class exports.ViewKey extends ApiaxleController
  @verb = "get"

  desc: -> "Get the definition of a key."

  docs: ->
    """
    ### Returns

    * The key object (including timestamps).
    """

  middleware: -> [ @mwKeyDetails( valid_api_required=true ) ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    @json res, req.key

class exports.DeleteKey extends ApiaxleController
  @verb = "delete"

  desc: -> "Delete a key."

  docs: ->
    """
    ### Returns

    * `true` on success.
    """

  middleware: -> [ @mwKeyDetails( valid_api_required=true ) ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    model = @app.model "key"

    model.del req.params.key, ( err, newKey ) =>
      return next err if err

      @json res, true

class exports.ModifyKey extends ApiaxleController
  @verb = "put"

  desc: -> "Update a key."

  docs: ->
    """
    Fields passed in will will be merged with the old key details.

    ### JSON fields supported

    #{ @app.model( 'key' ).getValidationDocs() }

    ### Returns

    * The newly inseted structure (including the new timestamp
      fields).
    """

  middleware: -> [
    @mwContentTypeRequired( ),
    @mwKeyDetails( valid_api_required=true )
  ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    model = @app.model "key"

    # validate the input
    model.validate req.body, ( err ) =>
      return next err if err

      # modify the key
      _.extend req.key, req.body

      # re-apply it to the db
      model.create req.params.key, req.key, ( err, newKey ) =>
        return next err if err

        @json res, newKey

class exports.ViewAllStatsForKey extends ApiaxleController
  @verb = "get"

  desc: -> "Get the statistics for a key."

  docs: ->
    """
    ### Returns

    * Object where the keys represent the HTTP status code of the
      endpoint or the error returned by apiaxle (QpsExceededError, for
      example). Each object contains date to hit count pairs.
    """

  middleware: -> [ @mwKeyDetails( valid_api_required=true ) ]

  path: -> "/v1/key/:key/stats"

  execute: ( req, res, next ) ->
    model = @app.model "counters"
    model.getPossibleResponseTypes req.params.key, ( err, types ) =>
      return next err if err

      multi = model.multi()

      for type in types
        do ( type ) ->
          multi.hgetall [ req.params.key, type ]

      multi.exec ( err, results ) =>
        return next err if err

        # build up the output structure
        output = {}

        for type in types
          output[ type ] = results.shift()

        return @json res, output
