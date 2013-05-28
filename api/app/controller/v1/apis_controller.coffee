{ StatsController, ListController } = require "../controller"

class exports.ApisCharts extends StatsController
  @verb = "get"

  path: -> "/v1/apis/charts"

  queryParams: ->
    {}=
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

  docs: ->
    {}=
      title: "Get the most used APIs and their hit counts."
      response: """List of the top 100 APIs and their hit rate for time
                   perioud GRANULATIRY"""

  execute: ( req, res, next ) ->
    @app.model( "stats" ).getScores [ "api" ], req.query.granularity, ( err, chart ) =>
      return next err if err
      return @json res, chart

class exports.ListApis extends ListController
  @verb = "get"

  path: -> "/v1/apis"

  queryParams: ->
    {}=
      type: "object"
      additionalProperties: false
      properties:
        from:
          type: "integer"
          default: 0
          docs: "Integer for the index of the first api you
                 want to see. Starts at zero."
        to:
          type: "integer"
          default: 10
          docs: "Integer for the index of the last api you want
                 to see. Starts at zero."
        resolve:
          type: "boolean"
          default: false
          docs: "If set to `true` then the details concerning the
                 listed apis will also be printed. Be aware that this
                 will come with a minor performace hit."

  docs: ->
    {}=
      verb: "GET"
      title: "List all APIs."
      response: """
        With <strong>resolve</strong>: An object mapping each API to the
        corresponding details.<br />
        Without <strong>resolve</strong>: An array with 1 API per entry
      """

  modelName: -> "apifactory"

  middleware: -> [ @mwValidateQueryParams() ]
