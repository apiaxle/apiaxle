{ ListController } = require "../controller"

class exports.ListKeyrings extends ListController
  @verb = "get"

  path: -> "/v1/keyrings"

  queryParams: ->
    params =
      type: "object"
      additionalProperties: false
      properties:
        from:
          type: "integer"
          default: 0
          docs: "Integer for the index of the first keyring you
                 want to see. Starts at zero."
        to:
          type: "integer"
          default: 10
          docs: "Integer for the index of the last keyring you want
                 to see. Starts at zero."
        resolve:
          type: "boolean"
          default: false
          docs: "If set to `true` then the details concerning the
                 listed keyrings will also be printed. Be aware that this
                 will come with a minor performace hit."

  docs: ->
    {}=
      verb: "GET"
      title: "List all KEYRINGs."
      response: """
        With <strong>resolve</strong>: An object mapping each keyring to the
        corresponding details.<br />
        Without <strong>resolve</strong>: An array with 1 keyring per entry
      """

  modelName: -> "keyringFactory"

  middleware: -> [ @mwValidateQueryParams() ]
