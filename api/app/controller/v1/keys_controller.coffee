{ ListController } = require "../controller"

class exports.ListKeys extends ListController
  @verb = "get"

  path: -> "/v1/keys"

  desc: -> "List all of the available keys."

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
    doc =
      verb: "GET"
      title: @desc()
      params: @queryParams().properties
      response: """
        With <strong>resolve</strong>: An object mapping each key to the
        corresponding details.<br />
        Without <strong>resolve</strong>: An array with 1 key per entry
      """
    return doc

  modelName: -> "keyFactory"

  middleware: -> [ @mwValidateQueryParams() ]
