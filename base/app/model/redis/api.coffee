{ ApiUnknown } = require "../../../lib/error"
{ Redis } = require "../redis"

validationEnv = require( "schema" )( "apiEnv" )

class exports.Api extends Redis
  @instantiateOnStartup = true

  @structure = validationEnv.Schema.create
    type: "object"
    additionalProperties: false
    properties:
      globalCache:
        type: "integer"
        docs: "The time in seconds that every call under this API should be cached."
        default: 0
      endPoint:
        type: "string"
        required: true
        docs: "The endpoint for the API. For example; `graph.facebook.com`"
      apiFormat:
        type: "string"
        enum: [ "json", "xml" ]
        default: "json"
        docs: "The resulting data type of the endpoint. This is redundant at the moment but will eventually support both XML too."
      endPointTimeout:
        type: "integer"
        default: 2
        docs: "Seconds to wait before timing out the connection"
      endPointMaxRedirects:
        type: "integer"
        default: 2
        docs: "Max redirects that are allowed when endpoint called."

  addKey: (api, key) ->
    @lpush "#{ api }:keys", key

  getKeys: (api, start, stop, cb) ->
    @lrange "#{ api }:keys", start, stop, cb
