_ = require "underscore"

{ StatsController,
  ApiaxleController,
  ListController } = require "../controller"
{ NotFoundError, AlreadyExists } = require "../../../lib/error"

class exports.ListKeys extends ListController
  @verb = "get"

  path: -> "/v1/keys"

  desc: -> "List all of the available keys."

  docs: ->
    """
    ### Supported query params
    * from: Integer for the index of the first key you want to
      see. Starts at zero.
    * to: Integer for the index of the last key you want to
      see. Starts at zero.
    * resolve: if set to `true` then the details concerning the listed
      keys will also be printed. Be aware that this will come with a
      minor performace hit.

    ### Returns

    * Without `resolve` the result will be an array with one key per
      entry.
    * If `resolve` is passed then results will be an object with the
      key name as the key and the details as the value.
    """

  modelName: -> "keyFactory"

class exports.CreateKey extends ApiaxleController
  @verb = "post"

  desc: -> "Provision a new key."

  docs: ->
    """
    ### JSON fields supported

    #{ @app.model( 'keyFactory' ).getValidationDocs() }

    ### Returns

    * The newly inseted structure (including the new timestamp
      fields).
    """

  middleware: -> [ @mwContentTypeRequired( ), @mwKeyDetails( ) ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    # error if it exists
    if req.key?
      return next new AlreadyExists "'#{ req.key.id }' already exists."

    @app.model( "keyFactory" ).create req.params.key, req.body, ( err, newObj ) =>
      return next err if err

      @json res, newObj.data

class exports.ViewKey extends ApiaxleController
  @verb = "get"

  desc: -> "Get the definition of a key."

  docs: ->
    """
    ### Returns

    * The key object (including timestamps).
    """

  middleware: -> [ @mwKeyDetails( valid_key_required=true ) ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    # we want to add the list of APIs supported by this key to the
    # output
    req.key.supportedApis ( err, apiNameList ) =>
      return next err if err

      # merge the api names with the current output
      output = req.key.data
      output.apis = apiNameList

      @json res, req.key.data

class exports.DeleteKey extends ApiaxleController
  @verb = "delete"

  desc: -> "Delete a key."

  docs: ->
    """
    ### Returns

    * `true` on success.
    """

  middleware: -> [ @mwKeyDetails( valid_key_required=true ) ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    model = @app.model "keyFactory"

    req.key.delete ( err ) =>
      return next err if err

      @json res, true

class exports.ModifyKey extends ApiaxleController
  @verb = "put"

  desc: -> "Update a key."

  docs: ->
    """
    Fields passed in will will be merged with the old key
    details. Note that in the case of updating a key's `QPD` it will
    get the new amount of calls minus the amount of calls it has
    already made.

    ### JSON fields supported

    #{ @app.model( 'keyFactory' ).getValidationDocs() }

    ### Returns

    * The newly inseted structure (including the new timestamp
      fields).
    """

  middleware: -> [
    @mwContentTypeRequired( ),
    @mwKeyDetails( valid_key_required=true )
  ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    req.key.update req.body, ( err, new_key ) =>
      return next err if err
      return @json res, new_key.data

class exports.ViewStatsForKey extends StatsController
  @verb = "get"

  desc: -> "Get stats for a key."

  docs: ->
    """
    #{ @paramDocs() }
    * forapi: Narrow results down to all statistics for the specified api.

    * Object where the keys represent timestamp for a given second
      and the values the amount of hits to the Key for that second
    """

  middleware: -> [ @mwKeyDetails( @app ) ]

  path: -> "/v1/key/:key/hits"

  execute: ( req, res, next ) ->
    model = @app.model "hits"
    model.getCurrentMinute "key", req.params.key, ( err, hits ) =>
      return @json res, hits


class exports.ViewHitsForKeyNow extends ApiaxleController
  @verb = "get"

  desc: -> "Get the real time hits for a key."

  docs: ->
    """
    ### Returns

    * Object where the keys represent the cache status (cached, uncached or
      error), each containing an object with response codes or error name,
      these in turn contain objects with timestamp:count
    """

  middleware: -> [ @mwKeyDetails( @app ) ]

  path: -> "/v1/key/:key/stats"

  execute: ( req, res, next ) ->
    axle_type      = "key"
    redis_key_part = [ req.key.id ]

    # narrow down to a particular key
    if for_key = req.query.forapi
      axle_type      = "key-api"
      redis_key_part = [ req.key.id, for_key ]

    @getStatsRange req, axle_type, redis_key_part, ( err, results ) =>
      return next err if err

      return @json res, results
