{ ListController } = require "../controller"

class exports.ListApis extends ListController
  @verb = "get"

  path: -> "/v1/apis"

  desc: -> "List all APIs."

  queryParams: ->
    params =
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
      title: @desc()
      response: """
        With <strong>resolve</strong>: An object mapping each API to the
        corresponding details.<br />
        Without <strong>resolve</strong>: An array with 1 API per entry
      """

  modelName: -> "apiFactory"

  middleware: -> [ @mwValidateQueryParams() ]
