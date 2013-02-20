_ = require "underscore"

{ ApiaxleController, ListController } = require "../controller"
{ AlreadyExists } = require "../../../lib/error"

class exports.UnlinkKeyToApi extends ApiaxleController
  @verb = "put"

  desc: ->
    """
    Disassociate a key with an API meaning calls to the API can no
    longer be made with the key.

    The key will still exist and its details won't be affected.
    """

  docs: ->
    """
    ### Returns

    * The unlinked key details.
    """

  middleware: -> [ @mwApiDetails( valid_api_required=true ),
                   @mwKeyDetails( valid_key_required=true ) ]

  path: -> "/v1/api/:api/unlinkkey/:key"

  execute: ( req, res, next ) ->
    req.api.unlinkKey req.key.id, ( err ) =>
      return next err if err

      @json res, req.key.data

class exports.LinkKeyToApi extends ApiaxleController
  @verb = "put"

  desc: ->
    """
    Associate a key with an API meaning calls to the API can be made
    with the key.

    The key must already exist and will not be modified by this
    operation.
    """

  docs: ->
    """
    ### Returns

    * The linked key details.
    """

  middleware: -> [ @mwApiDetails( valid_api_required=true ),
                   @mwKeyDetails( valid_key_required=true ) ]

  path: -> "/v1/api/:api/linkkey/:key"

  execute: ( req, res, next ) ->
    req.api.linkKey req.key.id, ( err ) =>
      return next err if err

      @json res, req.key.data

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

  middleware: -> [ @mwContentTypeRequired(),
                   @mwApiDetails( ) ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    # error if it exists
    if req.api?
      return next new AlreadyExists "'#{ req.api.id }' already exists."

    @app.model( "apiFactory" ).create req.params.api, req.body, ( err, newObj ) =>
      return next err if err

      @json res, newObj.data

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
    @json res, req.api.data

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
    model = @app.model "apiFactory"

    model.del req.params.api, ( err, newApi ) =>
      return next err if err

      @json res, true

class exports.ModifyApi extends ApiaxleController
  @verb = "put"

  desc: -> "Update an API."

  docs: ->
    """Will merge fields you pass in.

    ### JSON fields supported

    #{ @app.model( 'apiFactory' ).getValidationDocs() }

    ### Returns

    * The merged structure (including the timestamp fields).
    """

  middleware: -> [
    @mwContentTypeRequired( ),
    @mwApiDetails( valid_api_required=true )
  ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    model = @app.model "apiFactory"

    # modify the old api struct
    newData = _.extend req.api.data, req.body

    # re-apply it to the db
    model.create req.params.api, newData, ( err, newApi ) =>
      return next err if err

      @json res, newApi.data

class exports.ListApis extends ListController
  @verb = "get"

  path: -> "/v1/apis"

  desc: -> "List all APIs."

  docs: ->
    """
    ### Supported query params

    * from: Integer for the index of the first api you want to
      see. Starts at zero.
    * to: Integer for the index of the last api you want to
      see. Starts at zero.
    * resolve: if set to `true` then the details concerning the listed
      apis  will also be printed. Be aware that this will come with a
      minor performace hit.

    ### Returns

    * Without `resolve` the result will be an array with one api per
      entry.
    * If `resolve` is passed then results will be an object with the
      api name as the api and the details as the value.
    """

  modelName: -> "apiFactory"

class exports.ListApiKeys extends ListController
  @verb = "get"

  path: -> "/v1/api/:api/keys"

  desc: -> "List keys belonging to an API."

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

  middleware: -> [ @mwApiDetails( @app ) ]

  execute: ( req, res, next ) ->
    req.api.getKeys @from( req ), @to( req ), ( err, keys ) =>
      return next err if err
      return @json res, keys if not req.query.resolve?

      @resolve @app.model( "keyFactory" ), keys, ( err, results ) =>
        return cb err if err
        return @json res, results

class exports.ViewHitsForApi extends ApiaxleController
  @verb = "get"

  desc: -> "Get the statistics for an api."

  docs: ->
    """
    ### Returns

    * Object where the keys represent timestamp for a given second
      and the values the amount of hits to the specified API for that second
    """

  middleware: -> [ @mwApiDetails( @app ) ]

  path: -> "/v1/api/:api/hits"

  execute: ( req, res, next ) ->
    model = @app.model "hits"
    model.getCurrentMinute "api", req.params.api, ( err, hits ) =>
      return @json res, hits


class exports.ViewHitsForApiNow extends ApiaxleController
  @verb = "get"

  desc: -> "Get the statistics for an api."

  docs: ->
    """
    ### Returns

    * Integer, the number of hits to the API this second.
      Designed light weight real time statistics
    """

  middleware: -> [ @mwApiDetails( @app ) ]

  path: -> "/v1/api/:api/hits/now"

  execute: ( req, res, next ) ->
    model = @app.model "hits"
    model.getRealTime "api", req.params.api, ( err, hits ) =>
      return @json res, hits

class exports.ViewAllStatsForApi extends ApiaxleController
  @verb = "get"

  desc: -> "Get the statistics for an api."

  docs: ->
    """
    ### Returns

    * Object where the keys represent the HTTP status code of the
      endpoint or the error returned by apiaxle (QpsExceededError, for
      example). Each object contains date to hit count pairs.
    """

  middleware: -> [ @mwApiDetails( @app ) ]

  path: -> "/v1/api/:api/stats"

  execute: ( req, res, next ) ->
    model = @app.model "counters"
    model.getPossibleResponseTypes "api:#{ req.params.api }", ( err, types ) =>
      return next err if err

      multi  = model.multi()
      from   = req.query["from-date"]
      to     = req.query["to-date"]
      ranged = from and to

      for type in types
        do ( type ) =>
          if ranged
            multi = @getStatsRange multi, "api", req.params.api, type, from, to
          else
            multi.hgetall [ "api", req.params.api, type ]

      multi.exec ( err, results ) =>
        return next err if err

        # build up the output structure
        output = {}
        processed_results = []

        if ranged
          processed_results = @combineStatsRange results, from, to
        else
          processed_results = results

        for type in types
          output[ type ] = processed_results.shift()

        return @json res, output
