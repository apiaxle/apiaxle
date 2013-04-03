{ StatsController,
  ApiaxleController,
  ListController } = require "../controller"

class exports.ListKeyApis extends ListController
  @verb = "get"

  path: -> "/v1/key/:key/apis"

  desc: -> "List apis belonging to a key."

  queryParams: ->
    params =
      type: "object"
      additionalProperties: false
      properties:
        from:
          type: "integer"
          default: 0
          docs: "The index of the first api you want to
                 see. Starts at zero."
        to:
          type: "integer"
          default: 10
          docs: "The index of the last api you want to see. Starts at
                 zero."
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

    * Without `resolve` the result will be an array with one key per
      entry.
    * If `resolve` is passed then results will be an object with the
      key name as the key and the details as the value.
    """

  middleware: -> [ @mwKeyDetails( @app ),
                   @mwValidateQueryParams() ]

  execute: ( req, res, next ) ->
    req.key.supportedApis ( err, apis ) =>
      return next err if err
      return @json res, apis if not req.query.resolve

      @resolve @app.model( "apiFactory" ), apis, ( err, results ) =>
        return cb err if err

        output = _.map apiNameList, ( a ) ->
          "#{ req.protocol }://#{ req.headers.host }/v1/api/#{ a }"
        return @json res, output
