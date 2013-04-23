_ = require "lodash"

{ StatsController,
  ApiaxleController,
  ListController } = require "../controller"
{ NotFoundError, AlreadyExists } = require "../../../lib/error"

class exports.ListKeyApis extends ListController
  @verb = "get"

  path: -> "/v1/key/:key/apis"

  desc: -> "List apis belonging to a key."

  queryParams: ->
    params =
      type: "object"
      additionalProperties: false
      properties:
        from:
          type: "integer"
          default: 0
          docs: "The index of the first api you want to
                 see. Starts at zero."
        to:
          type: "integer"
          default: 10
          docs: "The index of the last api you want to see. Starts at
                 zero."
        resolve:
          type: "boolean"
          default: false
          docs: "If set to `true` then the details concerning the
                 listed apis will also be printed. Be aware that this
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

  middleware: -> [ @mwKeyDetails( @app ),
                   @mwValidateQueryParams() ]

  execute: ( req, res, next ) ->
    req.key.supportedApis ( err, apis ) =>
      return next err if err
      return @json res, apis if not req.query.resolve

      @resolve @app.model( "apiFactory" ), apis, ( err, results ) =>
        return cb err if err

        output = _.map apiNameList, ( a ) ->
          "#{ req.protocol }://#{ req.headers.host }/v1/api/#{ a }"
        return @json res, output

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

  middleware: -> [ @mwContentTypeRequired(),
                   @mwValidateQueryParams(),
                   @mwKeyDetails() ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    # error if it exists
    if req.key?
      return next new AlreadyExists "'#{ req.key.id }' already exists."

    @app.model( "keyFactory" ).create req.params.key, req.body, ( err, newObj ) =>
      return next err if err
      return @json res, newObj.data

class exports.ViewKey extends ApiaxleController
  @verb = "get"

  desc: -> "Get the definition of a key."

  docs: ->
    """
    ### Returns

    * The key object (including timestamps).
    """

  middleware: -> [ @mwValidateQueryParams(),
                   @mwKeyDetails( valid_key_required=true ) ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    # we want to add the list of APIs supported by this key to the
    # output
    req.key.supportedApis ( err, apiNameList ) =>
      return next err if err

      # merge the api names with the current output
      output = req.key.data
      output.apis = _.map apiNameList, ( a ) ->
        "#{ req.protocol }://#{ req.headers.host }/v1/api/#{ a }"
      return @json res, req.key.data

class exports.DeleteKey extends ApiaxleController
  @verb = "delete"

  desc: -> "Delete a key."

  docs: ->
    """
    ### Returns

    * `true` on success.
    """

  middleware: -> [ @mwValidateQueryParams(),
                   @mwKeyDetails( valid_key_required=true ) ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    model = @app.model "keyFactory"

    req.key.delete ( err ) =>
      return next err if err
      return @json res, true

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

    * The new structure and the old one.
    """

  middleware: -> [
    @mwContentTypeRequired( ),
    @mwKeyDetails( valid_key_required=true ),
    @mwValidateQueryParams()
  ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    req.key.update req.body, ( err, new_key, old_key ) =>
      return next err if err
      return @json res,
        new: new_key
        old: old_key

class exports.ViewHitsForKeyNow extends StatsController
  @verb = "get"

  desc: -> "Get the real time hits for a key."

  queryParams: ->
    current = super()

    # extends the base class queryParams
    _.extend current.properties,
      forapi:
        type: "string"
        optional: true
        docs: "Narrow results down to all statistics for the specified
               api."

    return current

  docs: ->
    """
    ### Returns

    * Object where the keys represent the cache status (cached, uncached or
      error), each containing an object with response codes or error name,
      these in turn contain objects with timestamp:count
    """

  middleware: -> [ @mwKeyDetails( @app ),
                   @mwValidateQueryParams() ]

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
