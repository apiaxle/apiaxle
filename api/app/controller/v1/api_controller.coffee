# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
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
    {}=
      verb: "PUT"
      title: "Disassociate a key with an API."
      response: "The Unlinked key details"

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
    {}=
      verb: "PUT"
      title: "Associate a key with an API"
      response: "The linked key details"
      description: """
        Calls to the API can be made with this key once this is run.
        <br />
        Both the key and the API must already exist before running.
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
    {}=
      verb: "POST"
      title: "Provision a new API."
      input: @app.model( 'apifactory' ).constructor.structure.properties
      response: "A JSON object containing API details"

  middleware: -> [ @mwValidateQueryParams()
                   @mwContentTypeRequired(),
                   @mwApiDetails( ) ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    # error if it exists
    if req.api?
      return next new AlreadyExists "'#{ req.api.id }' already exists."

    @app.model( "apifactory" ).create req.params.api, req.body, ( err, newObj ) =>
      return next err if err
      return @json res, newObj.data

class exports.ViewApi extends ApiaxleController
  @verb = "get"

  desc: -> "Get the definition for an API."

  docs: ->
    {}=
      verb: "GET"
      title: "Get the definition of an API"
      response: "The API structure (including the timestamp fields)."

  middleware: -> [ @mwValidateQueryParams()
                   @mwApiDetails( valid_api_required=true ) ]

  path: -> "/v1/api/:api"

  execute: ( req, res, next ) ->
    return @json res, req.api.data

class exports.DeleteApi extends ApiaxleController
  @verb = "delete"

  desc: -> "Delete an API."

  docs: ->
    {}=
      verb: "DELETE"
      title: "Delete an API"
      description: """
        <strong>Note:</strong> This will have no impact on any statistics or
        keys associated with the API
      """
      response: "TRUE on success"

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
    {}=
      verb: "PUT"
      title: "Update an API"
      description: """
        Will overwrite any fields specified in the input data.
        <br />
        Any unspecified will remain unchanged.
      """
      input: @app.model( 'apifactory' ).constructor.structure.properties
      response: "The new structure and the old one."

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
    {}=
      verb: "GET"
      title: "List keys belonging to an API."
      response: """
        With <strong>resolve</strong>: An object mapping each key to the
        corresponding details.<br />
        Without <strong>resolve</strong>: An array with 1 key per entry
      """

  middleware: -> [ @mwApiDetails( @app ),
                   @mwValidateQueryParams() ]

  execute: ( req, res, next ) ->
    { from, to } = req.query

    req.api.getKeys from, to, ( err, keys ) =>
      return next err if err

      pag =
        pagination: @pagination( req, keys.length )

      return @json res, keys, pag if not req.query.resolve

      @resolve @app.model( "keyfactory" ), keys, ( err, results ) =>
        return next err if err
        return @json res, results, pag

class exports.ViewAllStatsForApi extends StatsController
  @verb = "get"

  desc: -> "Get stats for an api."

  queryParams: ->
    current = super()

    # extends the base class queryParams
    _.extend current.properties,
      forkey:
        type: "string"
        optional: true
        docs: "Narrow results down to all statistics for the specified
               key."
      forkeyring:
        type: "string"
        optional: true
        docs: "Narrow results down to all statistics for the specified
               keyring."

    return current

  docs: ->
    {}=
      verb: "GET"
      title: "Get stats for an api"
      response: """
        Object where the keys represent the cache status (cached, uncached or
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

class exports.ApiKeyCharts extends StatsController
  @verb = "get"

  path: -> "/v1/api/:api/keycharts"

  middleware: -> [ @mwApiDetails( @app ),
                   @mwValidateQueryParams() ]

  docs: ->
    {}=
      title: "Get the most used keys for this api."
      response: """List of the top 100 keys and their hit rate for time
                   period GRANULARITY"""

  execute: ( req, res, next ) ->
    key = [ "api-key", req.api.id ]
    { granularity } = req.query

    @app.model( "stats" ).getScores key, granularity, ( err, chart ) =>
      return next err if err
      return @json res, chart

class exports.ApiTimerStats extends StatsController
  @verb = "get"

  desc: -> "Get timer stats for an api."

  docs: ->
    {}=
      verb: "GET"
      title: "Get timer stats for an api"
      response: """
        Object where the keys represent the type of timer, these in
        turn contain objects with timestamp: [ min, max, avg ]. The
        values in the array are a span of time measured in ms."""

  middleware: -> [ @mwApiDetails( @app ),
                   @mwValidateQueryParams() ]

  path: -> "/v1/api/:api/stats/timers"

  queryParams: ->
    current = super()
    delete current.properties.format_timeseries

    # extends the base class queryParams
    _.extend current.properties,
      debug:
        type: "string"
        optional: true
        default: false
        docs: "Show some ApiAxle related timings too."

    return current

  execute: ( req, res, next ) ->
    { from, to, granularity, format_timestamp, debug } = req.query

    model = @app.model "stattimers"

    # lob off the api name as it's redundant in this context
    timer_names = [ "http-request" ]
    timer_names.push "pre-request" if debug

    model.getValues req.api.id, timer_names, granularity, from, to, ( err, results ) =>
      return next err if err

      if format_timestamp isnt "epoch_seconds"
        results = @convertTimestamps req, results

      return next err if err
      return @json res, results

class exports.CapturePathStatsCounters extends StatsController
  @verb = "get"

  docs: ->
    {}=
      verb: "GET"
      title: "Capture path statistics."
      response: ""
      description: "List details stats for :capturepath"

  middleware: -> [ @mwValidateQueryParams()
                   @mwApiDetails( valid_api_required=true ) ]

  path: -> "/v1/api/:api/capturepath/:capturepath/stats/counters"

  queryParams: ->
    current = super()

    # extends the base class queryParams
    _.extend current.properties,
      forkey:
        type: "string"
        optional: true
        docs: "Narrow results down to all statistics for the specified
               key."
      forkeyring:
        type: "string"
        optional: true
        docs: "Narrow results down to all statistics for the specified
               keyring."

    return current

  execute: ( req, res, next ) ->
    { from, to, granularity, format_timestamp, debug, forkey, forkeyring } = req.query

    model = @app.model "capturepaths"

    namespace = [ "api", req.api.id ]
    if forkey
      namespace = [ "api-key", req.api.id, forkey ]
    else if forkeyring
      namespace = [ "api-keyring", req.api.id, forkeyring ]

    model.getCounters namespace, [ req.params.capturepath ], granularity, from, to, ( err, results ) =>
      return next err if err
      return @json res, results

class exports.CapturePathStatsTimings extends StatsController
  @verb = "get"

  docs: ->
    {}=
      verb: "GET"
      title: "Capture path statistics."
      response: ""
      description: "List details stats for :capturepath"

  middleware: -> [ @mwValidateQueryParams()
                   @mwApiDetails( valid_api_required=true ) ]

  path: -> "/v1/api/:api/capturepath/:capturepath/stats/timers"

  execute: ( req, res, next ) ->
    { from, to, granularity, format_timestamp, debug } = req.query

    model = @app.model "capturepaths"

    model.getTimers [ "api", req.api.id ], [ req.params.capturepath ], granularity, from, to, ( err, results ) =>
      return next err if err
      return @json res, results

class exports.ListCapturePaths extends ApiaxleController
  @verb = "get"

  docs: ->
    {}=
      verb: "GET"
      title: "List capture paths."
      response: "List of paths."
      description: "List all of the capture paths belonging to :api."

  middleware: -> [ @mwValidateQueryParams()
                   @mwApiDetails( valid_api_required=true ) ]

  path: -> "/v1/api/:api/capturepaths"

  execute: ( req, res, next ) ->
    { path } = req.params

    req.api.getCapturePaths ( err, paths ) =>
      return next err if err
      return @json res, paths

class exports.AddCapturePath extends ApiaxleController
  @verb = "put"

  docs: ->
    {}=
      verb: "PUT"
      title: "Add a capture path to :api"
      response: "The path added."
      description: "Add a path that will have statistics associated with it."

  middleware: -> [ @mwValidateQueryParams()
                   @mwApiDetails( valid_api_required=true ) ]

  path: -> "/v1/api/:api/addcapturepath/:path"

  execute: ( req, res, next ) ->
    { path } = req.params

    req.api.addCapturePath path, ( err ) =>
      return next err if err
      return @json res, path

class exports.DelCapturePath extends ApiaxleController
  @verb = "put"

  docs: ->
    {}=
      verb: "PUT"
      title: "Delete a capture path from :api"
      response: "The path removed."
      description: "Remove a path and prevent statistics being collected for it."

  middleware: -> [ @mwValidateQueryParams()
                   @mwApiDetails( valid_api_required=true ) ]

  path: -> "/v1/api/:api/delcapturepath/:path"

  execute: ( req, res, next ) ->
    { path } = req.params

    req.api.removeCapturePath path, ( err ) =>
      return next err if err
      return @json res, path

class exports.CapturePathsStatsTimings extends StatsController
  @verb = "get"

  docs: ->
    {}=
      verb: "GET"
      title: "View all capture path counts for :api."
      response: ""
      description: "All capture paths and their timings for :api."

  middleware: -> [ @mwValidateQueryParams()
                   @mwApiDetails( valid_api_required=true ) ]

  path: -> "/v1/api/:api/capturepaths/stats/timers"

  queryParams: ->
    current = super()

    # extends the base class queryParams
    _.extend current.properties,
      forkey:
        type: "string"
        optional: true
        docs: "Narrow results down to all statistics for the specified
               key."
      forkeyring:
        type: "string"
        optional: true
        docs: "Narrow results down to all statistics for the specified
               keyring."

    return current

  execute: ( req, res, next ) ->
    { from, to, granularity, format_timestamp, debug, forkey, forkeyring } = req.query

    model = @app.model "capturepaths"

    req.api.getCapturePaths ( err, paths ) =>
      return next err if err

      namespace = [ "api", req.api.id ]
      if forkey
        namespace = [ "api-key", req.api.id, forkey ]
      else if forkeyring
        namespace = [ "api-keyring", req.api.id, forkeyring ]

      model.getTimers namespace, paths, granularity, from, to, ( err, results ) =>
        return next err if err
        return @json res, results

class exports.CapturePathsStatsCounters extends StatsController
  @verb = "get"

  docs: ->
    {}=
      verb: "GET"
      title: "View all capture path counters for :api."
      response: ""
      description: "All capture paths and their counts for :api."

  middleware: -> [ @mwValidateQueryParams()
                   @mwApiDetails( valid_api_required=true ) ]

  path: -> "/v1/api/:api/capturepaths/stats/counters"

  queryParams: ->
    current = super()

    # extends the base class queryParams
    _.extend current.properties,
      forkey:
        type: "string"
        optional: true
        docs: "Narrow results down to all statistics for the specified
               key."
      forkeyring:
        type: "string"
        optional: true
        docs: "Narrow results down to all statistics for the specified
               keyring."

    return current

  execute: ( req, res, next ) ->
    { from, to, granularity, format_timestamp, debug, forkey, forkeyring } = req.query

    model = @app.model "capturepaths"

    req.api.getCapturePaths ( err, paths ) =>
      return next err if err

      namespace = [ "api", req.api.id ]
      if forkey
        namespace = [ "api-key", req.api.id, forkey ]
      else if forkeyring
        namespace = [ "api-keyring", req.api.id, forkeyring ]

      model.getCounters namespace, paths, granularity, from, to, ( err, results ) =>
        return next err if err
        return @json res, results
