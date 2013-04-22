_ = require "lodash"
async = require "async"

{ StatsController,
  ApiaxleController,
  ListController } = require "../controller"
{ AlreadyExists } = require "../../../lib/error"

class exports.UnlinkKeyFromApi extends ApiaxleController
  @verb = "put"

  desc: -> "Disassociate a key with an API."

  docs: ->
    """
    Calls to the API can no longer be made with the key once this has
    been called.

    The key will still exist and its details won't be affected.

    ### Returns

    * The unlinked key details.
    """

  middleware: -> [ @mwValidateQueryParams()
                   @mwApiDetails( valid_api_required=true ),
                   @mwKeyDetails( valid_key_required=true ) ]

  path: -> "/v1/api/:api/unlinkkey/:key"

  execute: ( req, res, next ) ->
    req.api.unlinkKeyById req.key.id, ( err ) =>
      return next err if err
      return @json res, req.key.data

class exports.LinkKeyToApi extends ApiaxleController
  @verb = "put"

  desc: -> "Associate a key with an API"

  docs: ->
    """
    Calls to the API can be made with the key once this is run.

    The key must already exist and will not be modified by this
    operation.

    ### Returns

    * The linked key details.
    """

  middleware: -> [ @mwValidateQueryParams()
                   @mwApiDetails( valid_api_required=true ),
                   @mwKeyDetails( valid_key_required=true ) ]

  path: -> "/v1/api/:api/linkkey/:key"

  execute: ( req, res, next ) ->
    req.api.linkKey req.key.id, ( err ) =>
      return next err if err
      return @json res, req.key.data

class exports.CreateApi extends ApiaxleController
  @verb = "post"

  desc: -> "Provision a new API."

  docs: ->
    """
    ### JSON fields supported

    #{ @app.model( 'apiFactory' ).getValidationDocs() }

    ### Returns

    * The inserted structure (including the new timestamp fields).
    """

  middleware: -> [ @mwValidateQueryParams()
                   @mwContentTypeRequired(),
                   @mwApiDetails( ) ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    # error if it exists
    if req.api?
      return next new AlreadyExists "'#{ req.api.id }' already exists."

    @app.model( "apiFactory" ).create req.params.api, req.body, ( err, newObj ) =>
      return next err if err
      return @json res, newObj.data

class exports.ViewApi extends ApiaxleController
  @verb = "get"

  desc: -> "Get the definition for an API."

  docs: ->
    """
    ### Returns

    * The API structure (including the timestamp fields).
    """

  middleware: -> [ @mwValidateQueryParams()
                   @mwApiDetails( valid_api_required=true ) ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    return @json res, req.api.data

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
    req.api.delete ( err, result ) =>
      return next err if err
      return @json res, true

class exports.ModifyApi extends ApiaxleController
  @verb = "put"

  desc: -> "Update an API."

  docs: ->
    """Will merge fields you pass in.

    ### JSON fields supported

    #{ @app.model( 'apiFactory' ).getValidationDocs() }

    ### Returns

    * The new structure and the old one.
    """

  middleware: -> [ @mwValidateQueryParams()
                   @mwContentTypeRequired( ),
                   @mwApiDetails( valid_api_required=true ) ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    req.api.update req.body, ( err, new_api, old_api ) =>
      return next err if err
      return @json res,
        new: new_api
        old: old_api

class exports.ListApiKeys extends ListController
  @verb = "get"

  path: -> "/v1/api/:api/keys"

  desc: -> "List keys belonging to an API."

  queryParams: ->
    params =
      type: "object"
      additionalProperties: false
      properties:
        from:
          type: "integer"
          default: 0
          docs: "The index of the first key you want to
                 see. Starts at zero."
        to:
          type: "integer"
          default: 10
          docs: "The index of the last key you want to see. Starts at
                 zero."
        resolve:
          type: "boolean"
          default: false
          docs: "If set to `true` then the details concerning the
                 listed keys will also be printed. Be aware that this
                 will come with a minor performace hit."

  docs: ->
    """
    ### Supported query params

    #{ @queryParamDocs() }

    ### Returns

    * Without `resolve` the result will be an array with one key per
      entry.
    * If `resolve` is passed then results will be an object with the
      key name as the key and the details as the value.
    """

  middleware: -> [ @mwApiDetails( @app ),
                   @mwValidateQueryParams() ]

  execute: ( req, res, next ) ->
    { from, to } = req.query

    req.api.getKeys from, to, ( err, keys ) =>
      return next err if err
      return @json res, keys if not req.query.resolve

      @resolve @app.model( "keyFactory" ), keys, ( err, results ) =>
        return next err if err

        output = _.map results, ( k ) ->
          "#{ req.protocol }://#{ req.headers.host }/v1/key/#{ k }"
        return @json res, results

class exports.ViewAllStatsForApi extends StatsController
  @verb = "get"

  desc: -> "Get stats for an api."

  queryParams: ->
    current = super()

    # extends the base class queryParams
    _.extend current,
      forkey:
        type: "string"
        optional: true
        docs: "Narrow results down to all statistics for the specified
               key."

    return current

  docs: ->
    """
    ### Supported query params

    #{ @queryParamDocs() }

    ### Returns

    * Object where the keys represent the cache status (cached, uncached or
      error), each containing an object with response codes or error name,
      these in turn contain objects with timestamp:count
    """

  middleware: -> [ @mwApiDetails( @app ),
                   @mwValidateQueryParams() ]

  path: -> "/v1/api/:api/stats"

  execute: ( req, res, next ) ->
    axle_type      = "api"
    redis_key_part = [ req.api.id ]

    # narrow down to a particular api
    if for_key = req.query.forkey
      axle_type      = "api-key"
      redis_key_part = [ req.api.id, for_key ]

    @getStatsRange req, axle_type, redis_key_part, ( err, results ) =>
      return next err if err

      # timeseries
      if req.query.format_timeseries
        return @denormForTimeseries results, ( err, new_results ) =>
          return next err if err
          return @json res, new_results

      return @json res, results
