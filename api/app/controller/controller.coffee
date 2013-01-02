moment = require "moment"
_      = require "underscore"

{ Controller } = require "apiaxle.base"

{ KeyNotFoundError,
  ApiNotFoundError,
  KeyringNotFoundError,
  InvalidContentType,
  ApiUnknown,
  ApiKeyError } = require "../../lib/error"

class exports.ApiaxleController extends Controller
  # Used output data conforming to a standard Api Axle
  # format. Includes a metadata field
  json: ( res, results ) ->
    output =
      meta:
        version: 1
        status_code: res.statusCode
      results: results

    return res.json output

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
    from  = moment(from_date)
    to    = moment(to_date)
    days  = to.diff from, "days"

    for i in [0..days]
      date = from.format "YYYY-M-D"
      from.add "days",1
      multi.hgetall [ stat_type, stat_key, date, response_type ]

    return multi

  combineStatsRange: ( results, from_date, to_date ) ->
    from  = moment(from_date)
    to    = moment(to_date)
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
  @default_from = 0
  @default_to   = 100

  # calculate from and to
  from: ( req ) ->
    return ( req.query.from or @constructor.default_from )

  to: ( req ) ->
    return ( req.query.to or @constructor.default_to )

  execute: ( req, res, next ) ->
    model = @app.model( @modelName() )

    model.range @from( req ), @to( req ), ( err, keys ) =>
      return next err if err

      # if we're not asked to resolve the items then just bung the
      # list back
      if not req.query.resolve?
        return @json res, keys

      # now bind the actual results to the keys
      @resolve model, keys, ( err, results ) =>
        return next err if err

        @json res, results
