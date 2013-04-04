moment = require "moment"
_      = require "underscore"
async  = require "async"

{ Controller, validate } = require "apiaxle-base"

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
  json: ( res, results ) ->
    output =
      meta:
        version: 1
        status_code: res.statusCode
      results: results

    return res.json output

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
    # build up the requests, grab the keys and zip into a new
    # hash
    multi = model.multi()
    for result in keys
      multi.hgetall result

    final = {}

    # grab the accumulated keys
    multi.exec ( err, accKeys ) ->
      return cb err if err

      i = 0
      for result in keys
        final[ result ] = accKeys[ i++ ]

      return cb null, final

  mwValidateQueryParams: ( ) ->
    ( req, res, next ) =>
      return next() if not @queryParams?

      validators = @queryParams()

      for key, val of req.query
        # find out what type we expect
        break unless validators.properties?[ key ]?
        suggested_type = validators.properties[ key ].type

        # convert int if need be
        if suggested_type is "integer"
          req.query[ key ] = parseInt( val )
          continue

        if suggested_type is "boolean"
          req.query[ key ] = ( val is "true" )
          continue

      validate validators, req.query, ( err, with_defaults ) ->
        return next err if err

        # replace the old ones
        req.query = with_defaults
        return next()

  # Will decorate `req.key` with details of the key specified in the
  # `:key` parameter. If `valid_key_required` is truthful then an
  # error will be thrown if a valid key wasn't found.
  mwKeyDetails: ( valid_key_required=false ) ->
    ( req, res, next ) =>
      key = req.params.key

      @app.model( "keyFactory" ).find key, ( err, dbKey ) ->
        return next err if err

        if valid_key_required and not dbKey?
          return next new KeyNotFoundError "Key '#{ key }' not found."

        req.key = dbKey

        return next()

  # Will decorate `req.keyring` with details of the keyring specified
  # in the `:keyring` parameter. If `valid_keyring_required` is
  # truthful then an error will be thrown if a valid keyring wasn't
  # found.
  mwKeyringDetails: ( valid_keyring_required=false ) ->
    ( req, res, next ) =>
      keyring = req.params.keyring

      @app.model( "keyringFactory" ).find keyring, ( err, dbKeyring ) ->
        return next err if err

        # do we /need/ the keyring to exist?
        if valid_keyring_required and not dbKeyring?
          return next new KeyringNotFoundError "Keyring '#{ keyring }' not found."

        req.keyring = dbKeyring

        return next()

  # Will decorate `req.api` with details of the api specified in the
  # `:api` parameter. If `valid_api_required` is truthful then an
  # error will be thrown if a valid api wasn't found.
  mwApiDetails: ( valid_api_required=false ) ->
    ( req, res, next ) =>
      api = req.params.api

      @app.model( "apiFactory" ).find api, ( err, dbApi ) ->
        return next err if err

        # do we /need/ the api to exist?
        if valid_api_required and not dbApi?
          return next new ApiNotFoundError "Api '#{ api }' not found."

        req.api = dbApi

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

  # Gets a range of stats from Redis
  # Stats are keyed by stat_type ('api' or 'key') and day
  # Returns a Redis multi
  getStatsRange: ( multi, stat_type, stat_key, response_type, from_date, to_date ) ->
    from  = moment( from_date )
    to    = moment( to_date )
    days  = to.diff from, "days"

    for i in [0..days]
      date = from.format "YYYY-M-D"
      from.add "days",1
      multi.hgetall [ stat_type, stat_key, date, response_type ]

    return multi

  combineStatsRange: ( results, from_date, to_date ) ->
    from  = moment( from_date )
    to    = moment( to_date )
    days  = to.diff from, "days"

    processed_results = []
    while results.length > 0
      merged = {}
      for i in [0..days]
        result = results.shift()
        merged = _.extend merged, result
      processed_results.push merged

    return processed_results

class exports.ListController extends exports.ApiaxleController
  execute: ( req, res, next ) ->
    model = @app.model @modelName()

    { from, to } = req.query

    model.range from, to, ( err, keys ) =>
      return next err if err

      # if we're not asked to resolve the items then just bung the
      # list back
      return @json res, keys if not req.query.resolve

      # now bind the actual results to the keys
      @resolve model, keys, ( err, results ) =>
        return next err if err
        return @json res, results

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
          default: Math.floor( ( new Date() ).getTime() / 1000 ) - 600
          docs: "The unix epoch from which to start gathering
                 the statistics. Defaults to `now - 10 minutes`."
        to:
          type: "integer"
          default: Math.floor( ( new Date() ).getTime() / 1000 )
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

  getStatsRange: ( req, axle_type, key_parts, cb ) ->
    model = @app.model "stats"
    types = [ "uncached", "cached", "error" ]

    # all managed by queryParams
    { from, to, granularity } = req.query

    all = []
    _.each types, ( type ) =>
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

      return cb null, processed
