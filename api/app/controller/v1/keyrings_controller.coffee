{ ListController } = require "../controller"

class exports.ListKeyrings extends ListController
  @verb = "get"

  path: -> "/v1/keyrings"

  desc: -> "List all KEYRINGs."

  docs: ->
    """
    ### Supported query params

    * from: Integer for the index of the first keyring you want to
      see. Starts at zero.
    * to: Integer for the index of the last keyring you want to
      see. Starts at zero.
    * resolve: if set to `true` then the details concerning the listed
      keyrings  will also be printed. Be aware that this will come with a
      minor performace hit.

    ### Returns

    * Without `resolve` the result will be an array with one keyring per
      entry.
    * If `resolve` is passed then results will be an object with the
      keyring name as the keyring and the details as the value.
    """

  modelName: -> "keyringFactory"
