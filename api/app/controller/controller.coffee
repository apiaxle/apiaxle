_ = require "lodash"
async = require "async"
qs = require "querystring"

{ validate } = require "scarf"
{ Controller } = require "scarf"

{ KeyNotFoundError,
  ApiNotFoundError,
  KeyringNotFoundError,
  InvalidContentType,
  InvalidGranularityType,
  ApiUnknown,
  ApiKeyError } = require "../../lib/error"

class exports.ApiaxleController extends Controller
  queryParamDocs: ( ) ->
    strings = for field, details of @queryParams().properties
      continue unless details.docs?

      docs = "Undocumented."
      if details.docs
        docs = details.docs.replace( /[ \n]+/g, " " )

      out = "* #{ field }: "
      out += "(default: #{ details.default }) " if details.default
      out += "One of: #{ details.enum.join ', ' }. " if details.enum
      out += "#{ docs }"

    return strings.join "\n"

  # Used output data conforming to a standard Api Axle
  # format. Includes a metadata field
  json: ( res, results, extra_meta ) ->
    output =
      meta:
        version: 1
        status_code: res.statusCode
      results: results

    # add our new meta, if there is any
    output.meta = _.merge output.meta, extra_meta if extra_meta

    return res.json res.statusCode, output

  # By default there are no query parameters and adding them will
  # cause an error. Only affects controllers which use the
  # `mwValidateQueryParams` middleware.
  queryParams: ->
    params =
      type: "object"
      additionalProperties: false

  # This function is used to satisfy the `?resolve=true` type
  # parameters. Given a bunch of keys, go off to the respective bits
  # of redis to resolve the data.
  resolve: ( model, keys, cb ) ->
    model.find keys, ( err, results ) ->
      return cb err if err

      all = {}
      for id, data of results
        all[id] = if data.data? then data.data else data

      return cb null, all

  mwValidateQueryParams: ( ) ->
    ( req, res, next ) =>
      return next() if not @queryParams?

      validators = @queryParams()

      for key, val of req.query
        # find out what type we expect
        continue unless validators.properties?[ key ]?
        suggested_type = validators.properties[ key ].type

        # convert int if need be
        if suggested_type is "integer"
          req.query[ key ] = parseInt( val )
          continue

        if suggested_type is "boolean"
          req.query[ key ] = ( val is "true" )
          continue

      validate validators, req.query, true, ( err, with_defaults ) ->
        return next new ValidationError err.message if err

        # replace the old ones
        req.query = with_defaults
        return next()

  # Will decorate `req.key` with details of the key specified in the
  # `:key` parameter. If `valid_key_required` is truthful then an
  # error will be thrown if a valid key wasn't found.
  mwKeyDetails: ( valid_key_required=false ) ->
    ( req, res, next ) =>
      key = req.params.key

      @app.model( "keyfactory" ).find [ key ], ( err, results ) ->
        return next err if err

        if valid_key_required and not results[key]?
          return next new KeyNotFoundError "Key '#{ key }' not found."

        req.key = results[key]

        return next()

  # Will decorate `req.keyring` with details of the keyring specified
  # in the `:keyring` parameter. If `valid_keyring_required` is
  # truthful then an error will be thrown if a valid keyring wasn't
  # found.
  mwKeyringDetails: ( valid_keyring_required=false ) ->
    ( req, res, next ) =>
      keyring = req.params.keyring

      @app.model( "keyringfactory" ).find [ keyring ], ( err, results ) ->
        return next err if err

        # do we /need/ the keyring to exist?
        if valid_keyring_required and not results[keyring]?
          return next new KeyringNotFoundError "Keyring '#{ keyring }' not found."

        req.keyring = results[keyring]

        return next()

  # Will decorate `req.api` with details of the api specified in the
  # `:api` parameter. If `valid_api_required` is truthful then an
  # error will be thrown if a valid api wasn't found.
  mwApiDetails: ( valid_api_required=false ) ->
    ( req, res, next ) =>
      api = req.params.api

      @app.model( "apifactory" ).find [ api ], ( err, results ) ->
        return next err if err

        # do we /need/ the api to exist?
        if valid_api_required and not results[api]?
          return next new ApiNotFoundError "Api '#{ api }' not found."

        req.api = results[api]

        return next()

  # Make a call require a specific content-type `accepted` can be an
  # array of good types. Without one of the valid content types
  # supplied there will be an error.
  mwContentTypeRequired: ( accepted=[ "application/json" ] ) ->
    ( req, res, next ) ->
      ct = req.headers[ "content-type" ]

      if not ct
        return next new InvalidContentType "Content-type is a required header."

      if ct not in accepted
        return next new InvalidContentType "#{ ct } is not a supported content type."

      return next()

class exports.ListController extends exports.ApiaxleController
  pagination: ( req, results_count ) ->
    url = "#{ req.protocol }://#{ req.headers.host }#{ req.path }"
    { from, to } = req.query

    pagination = {}

    jump = ( to - from )

    if results_count >= jump
      next_params = req.query
      next_params.from = ( to + 1 )
      next_params.to = ( next_params.from + jump ) + 1
      pagination.next = "#{ url}?#{ qs.stringify next_params }"

    if from > 0
      prev_params = req.query
      prev_params.from = if ( from - jump ) <= 0 then 0 else jump
      prev_params.to = from
      pagination.prev = "#{ url}?#{ qs.stringify prev_params }"

    return pagination

  execute: ( req, res, next ) ->
    model = @app.model @modelName()

    { from, to } = req.query

    model.range from, to, ( err, keys ) =>
      return next err if err

      # if we're not asked to resolve the items then just bung the
      # list back
      if not req.query.resolve
        return @json res, keys, { pagination: @pagination( req, keys.length ) }

      # now bind the actual results to the keys
      @resolve model, keys, ( err, results ) =>
        return next err if err
        return @json res, results, { pagination: @pagination( req, keys.length ) }

class exports.StatsController extends exports.ApiaxleController
  queryParams: ->
    # get the correct granularities from the model itself.
    if not @valid_granularities
      gran_details = @app.model( "stats" ).constructor.granularities
      @valid_granularities = _.keys gran_details

    params =
      type: "object"
      additionalProperties: false
      properties:
        from:
          type: "integer"
          default: Math.floor( Date.now() / 1000 ) - 600
          docs: "The unix epoch from which to start gathering
                 the statistics. Defaults to `now - 10 minutes`."
        to:
          type: "integer"
          default: Math.floor( Date.now() / 1000 )
          docs: "The unix epoch from which to finish gathering
                 the statistics. Defaults to `now`."
        granularity:
          type: "string"
          enum: @valid_granularities
          default: "minutes"
          docs: "Allows you to gather statistics tuned to this level
                 of granularity. Results will still arrive in the form
                 of an epoch to results pair but will be rounded off
                 to the nearest unit."
        format_timeseries:
          type: "boolean"
          default: false
          docs: "Results will be returned in a format more suited to
                 generating timeseries graphs."

  getStatsRange: ( req, axle_type, key_parts, cb ) ->
    model = @app.model "stats"
    types = [ "uncached", "cached", "error" ]

    # all managed by queryParams
    { from, to, granularity } = req.query

    all = []
    for type in types
      do( type ) =>
        all.push ( cb ) =>
          # axle_type probably one of "key", "api", "api-key",
          # "key-api" at the moment
          redis_key = [ axle_type ]
          redis_key = redis_key.concat key_parts
          redis_key.push type

          model.getAll redis_key, granularity, from, to, cb

    async.series all, ( err, results ) =>
      return cb err if err

      processed = {}
      for type, idx in types
        processed[type] = results[idx]

      # timeseries
      if req.query.format_timeseries is true
        return @denormForTimeseries processed, ( err, new_results ) =>
          return next err if err
          return cb null, new_results

      return cb null, processed

  # TODO: zero padding?
  denormForTimeseries: ( results, cb ) ->
    new_results = {}
    all = {}

    for type, details of results
      all[type] ||= {}
      for time, status_count of details
        for status, count of status_count
          all[type][status] ||= {}
          all[type][status][time] = count

    return cb null, all
