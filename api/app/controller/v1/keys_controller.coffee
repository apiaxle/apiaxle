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
          default: "minutes"
          docs: "Get charts for the most recent values in the most
                 recent GRANULARTIY."

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
