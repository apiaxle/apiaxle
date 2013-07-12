{ ApiUnknown,
  ValidationError,
  KeyNotFoundError } = require "../../../lib/error"
{ KeyContainerModel, Redis } = require "../redis"

class Api extends KeyContainerModel
  @reverseLinkFunction = "linkToApi"
  @reverseUnlinkFunction = "unlinkFromApi"
  @factory = "apifactory"

  isDisabled: ( ) -> @data.disabled

  getCapturePaths: ( cb ) ->
    @hgetall [ "capture-paths" ], cb

  removeCapturePath: ( name, cb ) ->
    @hdel [ "capture-paths" ], name, ( err ) =>
      return cb err if err

      @hlen [ "capture-paths" ], ( err, length ) =>
        return err if err

        # if we're now empty then we need to let redis know
        if length is 0
          @data.hasCapturePaths = false
          return @hset @id, "hasCapturePaths", false, cb

        return cb null, true

  addCapturePath: ( name, path, cb ) ->
    multi = @multi()
    multi.hset [ "capture-paths" ], name, path

    # we also need to make sure the current object knows that there
    # are paths set for fast access in the proxy
    @data.hasCapturePaths = true
    multi.hset @id, "hasCapturePaths", true
    multi.exec cb

class exports.ApiFactory extends Redis
  @instantiateOnStartup = true
  @returns = Api
  @structure =
    type: "object"
    additionalProperties: false
    properties:
      createdAt:
        type: "integer"
        optional: true
      updatedAt:
        type: "integer"
        optional: true
      globalCache:
        type: "integer"
        docs: "The time in seconds that every call under this API should be cached."
        default: 0
      endPoint:
        type: "string"
        required: true
        docs: "The endpoint for the API. For example; `graph.facebook.com`"
      protocol:
        type: "string"
        enum: [ "https", "http" ]
        default: "http"
        docs: "The protocol for the API, whether or not to use SSL"
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
      extractKeyRegex:
        type: "string"
        docs: "Regular expression used to extract API key from url. Axle will use the **first** matched grouping and then apply that as the key. Using the `api_key` or `apiaxle_key` will take precedence."
        optional: true
        is_valid_regexp: true
      defaultPath:
        type: "string"
        optional: true
        docs: "An optional path part that will always be called when the API is hit."
      disabled:
        type: "boolean"
        default: false
        docs: "Disable this API causing errors when it's hit."
      strictSSL:
        type: "boolean"
        default: true
        docs: "Set to true to require that SSL certificates be valid"
      hasCapturePaths:
        type: "boolean"
        default: false
        docs: "When true ApiAxle will parse and capture bits of information about the API being called."

