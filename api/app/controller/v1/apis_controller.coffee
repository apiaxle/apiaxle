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
    """
    ### Supported query params

    #{ @queryParamDocs() }

    ### Returns

    * Without `resolve` the result will be an array with one api per
      entry.
    * If `resolve` is passed then results will be an object with the
      api name as the api and the details as the value.
    """

  modelName: -> "apifactory"

  middleware: -> [ @mwValidateQueryParams() ]
