# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
async = require "async"
{ StatsController, ListController } = require "../controller"

class exports.KeysCharts extends StatsController
  @verb = "get"

  path: -> "/v1/keys/charts"

  queryParams: ->
    {} =
      type: "object"
      additionalProperties: false
      properties:
        granularity:
          type: "string"
          enum: @valid_granularities
          default: "minute"
          docs: "Get charts for the most recent values in the most
                 recent GRANULARTIY."

  docs: ->
    {}=
      title: "Get the most used keys and their hit counts."
      response: """List of the top 100 keys and their hit rate for time
                   perioud GRANULATIRY"""

  middleware: -> [ @mwValidateQueryParams() ]

  execute: ( req, res, next ) ->
    @app.model( "stats" ).getScores [ "key" ], req.query.granularity, ( err, chart ) =>
      return next err if err
      return @json res, chart

class exports.ListKeys extends ListController
  @verb = "get"

  path: -> "/v1/keys"

  queryParams: ->
    params =
      type: "object"
      additionalProperties: false
      properties:
        from:
          type: "integer"
          default: 0
          docs: "The index of the first key you want to see. Starts at
                 zero."
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
      title: "List all of the available keys."
      response: """
        With <strong>resolve</strong>: An object mapping each key to the
        corresponding details.<br />
        Without <strong>resolve</strong>: An array with 1 key per entry
      """

  modelName: -> "keyfactory"

  middleware: -> [ @mwValidateQueryParams() ]

class exports.AllKeyStats extends StatsController
  @verb = "get"

  path: -> "/v1/keys/all"

  docs: ->
    {}=
      verb: "GET"
      title: "List stats for all available keys."
      response: """
        Return stats for all available keys.
      """

  middleware: -> [ @mwValidateQueryParams() ]

  execute: ( req, res, next ) ->
    model = @app.model "keyfactory"

    { from, to, granularity } = req.query

    model.nonAnonymousKeys ( err, keys ) =>
      return next err if err

      statsModel = @app.model "stats"

      types = [ "uncached", "cached", "error" ]

      keyFns = []
      apiKeysResult = {}
      for key in keys
        do( key ) =>
          keyFns.push ( cb ) =>
            queryTypeFns = {}
            for type in types
              do( type ) =>
                queryTypeFns[type] = ( cb ) =>
                  redis_key = ['key', key, type]
                  statsModel.getAll redis_key, granularity, from, to, cb
            async.parallel queryTypeFns, ( err, timestampData ) =>
              return err if err
              apiKeysResult[key] = timestampData
              cb null

      return async.series keyFns, ( err ) =>
        return next err if err
        return @json res, apiKeysResult
