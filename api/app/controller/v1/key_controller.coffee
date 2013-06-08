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
        resolve:
          type: "boolean"
          default: false
          docs: "If set to `true` then the details concerning the
                 listed apis will also be printed. Be aware that this
                 will come with a minor performace hit."

  docs: ->
    {}=
      verb: "GET"
      title: "List apis belonging to a key."
      response: """
        With <strong>resolve</strong>: An object mapping each key to the
        corresponding details.<br />
        Without <strong>resolve</strong>: An array with 1 key per entry
      """

  middleware: -> [ @mwKeyDetails( @app ),
                   @mwValidateQueryParams() ]

  execute: ( req, res, next ) ->
    req.key.supportedApis ( err, apis ) =>
      return next err if err

      resources = _.map apis, ( k ) ->
        "#{ req.protocol }://#{ req.headers.host }/v1/api/#{ k }"

      return @json res, resources if not req.query.resolve

      @resolve @app.model( "apifactory" ), apis, ( err, results ) =>
        return next err if err
        return @json res, _.object resources, _.values( results )

class exports.CreateKey extends ApiaxleController
  @verb = "post"

  desc: -> "Provision a new key."

  docs: ->
    {}=
      verb: "POST"
      title: "Provision a new key."
      input: @app.model( 'keyfactory' ).constructor.structure.properties
      response: """
        The newly inserted structure (including the new timestamp fields).
      """

  middleware: -> [ @mwContentTypeRequired(),
                   @mwValidateQueryParams(),
                   @mwKeyDetails() ]

  queryParams: ->
    {}=
      type: "object"
      additionalProperties: false
      properties:
        isNSA:
          type: "boolean"
          default: false
          docs: """If you're the NSA set this flag to true and you'll
            activate GOD mode getting you into any API regardless of
            your being linked to it or not."""

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    # error if it exists
    if req.key?
      return next new AlreadyExists "'#{ req.key.id }' already exists."

    @app.model( "keyfactory" ).create req.params.key, req.body, ( err, newObj ) =>
      return next err if err
      return @json res, newObj.data

class exports.ViewKey extends ApiaxleController
  @verb = "get"

  desc: -> "Get the definition of a key."

  docs: ->
    {}=
      verb: "GET"
      title: "Get the definition of a key."
      response: "The key object (including timestamps)."

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
    {}=
      verb: "DELETE"
      title: "Delete a key."
      response: "TRUE on success"

  middleware: -> [ @mwValidateQueryParams(),
                   @mwKeyDetails( valid_key_required=true ) ]

  path: -> "/v1/key/:key"

  execute: ( req, res, next ) ->
    model = @app.model "keyfactory"

    req.key.delete ( err ) =>
      return next err if err
      return @json res, true

class exports.ModifyKey extends ApiaxleController
  @verb = "put"

  desc: -> "Update a key."

  docs: ->
    {}=
      verb: "PUT"
      title: "Update a key."
      description: """
        Fields passed in will will be merged with the old key
        details.
        <br />
        <strong>Note:</strong> In the case of updating a key's `QPD` it will
        get the new amount of calls minus the amount of calls it has
        already made.
      """
      input: @app.model( 'keyfactory' ).constructor.structure.properties
      response: "The new structure and the old one."

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
    {}=
      verb: "GET"
      title: "Get the real time hits for a key."
      response: """
        Object where the keys represent the cache status (cached,
        uncached or error), each containing an object with response
        codes or error name, these in turn contain objects with
        timestamp:count
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

class exports.KeyApiCharts extends StatsController
  @verb = "get"

  path: -> "/v1/key/:key/apicharts"

  queryParams: ->
    {}=
      type: "object"
      additionalProperties: false
      properties:
        granularity:
          type: "string"
          enum: @valid_granularities
          default: "minute"
          docs: "Get charts for the most recent values in the most
                 recent GRANULARTIY."

  middleware: -> [ @mwKeyDetails( @app ),
                   @mwValidateQueryParams() ]

  docs: ->
    {}=
      title: "Get the most used apis for this key."
      response: """List of the top 100 APIs and their hit rate for time
                   period GRANULARITY"""

  execute: ( req, res, next ) ->
    key = [ "key-api", req.key.id ]
    { granularity } = req.query

    @app.model( "stats" ).getScores key, granularity, ( err, chart ) =>
      return next err if err
      return @json res, chart
