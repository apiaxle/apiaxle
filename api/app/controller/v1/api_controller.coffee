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
    doc =
      verb: "PUT"
      title: "Disassociate a key with an API."
      response: "The Unlinked key details"
    return doc

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
    doc =
      verb: "PUT"
      title: "Associate a key with an API"
      response: "The linked key details"
      description: """
        Calls to the API can be made with this key once this is run.
        <br />
        Both the key and the API must already exist before running.
        """
    return doc

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
    doc =
      verb: "POST"
      title: "Provision a new API."
      input:
        endPoint: "String (required)"
        protocol: "String (default 'http')"
        apiFormat: "String (default 'json')"
        globalCache: "Time in seconds that each API call should be cached"
        endPointTimeout: "Time in seconds before timing out the connection (default 2)"
        endPointMaxRedirects: "Integer (default 2)"
        extractKeyRegex: "String, regular expression used to extract key from URL. See usage example"
        disabled: "Boolean"
      response: "A JSON object containing API details"
    return doc

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
    doc =
      verb: "GET"
      title: "Get the definition of an API"
      response: "The API structure (including the timestamp fields)."
    return doc

  middleware: -> [ @mwValidateQueryParams()
                   @mwApiDetails( valid_api_required=true ) ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    return @json res, req.api.data

class exports.DeleteApi extends ApiaxleController
  @verb = "delete"

  desc: -> "Delete an API."

  docs: ->
    doc =
      verb: "DELETE"
      title: "Delete an API"
      description: """
        <strong>Note:</strong> This will have no impact on any statistics or
        keys associated with the API
      """
      response: "TRUE on success"
    return doc


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
    doc =
      verb: "PUT"
      title: "Update an API"
      description: """
        Will overwrite any fields specified in the input data.
        <br />
        Any unspecified will remain unchanged.
      """
      input:
        globalCache: "The time in seconds that every call under this API should be cached."
        endPoint: "The endpoint for the API. For example; graph.facebook.com"
        protocol: "(default: http) The protocol for the API, whether or not to use SSL"
        apiFormat: "(default: json) The resulting data type of the endpoint. This is redundant at the moment but will eventually support both XML too."
        endPointTimeout: "(default: 2) Seconds to wait before timing out the connection"
        endPointMaxRedirects: "(default: 2) Max redirects that are allowed when endpoint called."
        extractKeyRegex: "Regular expression used to extract API key from url. Axle will use the first matched grouping and then apply that as the key. Using the api_key or apiaxle_key will take precedence."
        defaultPath: "An optional path part that will always be called when the API is hit."
        disabled: "Disable this API causing errors when it’s hit."
      response: "The new structure and the old one."
    return doc

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
    doc =
      verb: "GET"
      title: "List keys belonging to an API."
      params: @queryParams().properties
      response: """
        With <strong>resolve</strong>: An object mapping each key to the
        corresponding details.<br />
        Without <strong>resolve</strong>: An array with 1 key per entry
      """
    return doc

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
      return @json res, results
