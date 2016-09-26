# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
{ ApiUnknown,
  ValidationError,
  KeyNotFoundError } = require "../../../lib/error"
{ KeyContainerModel, Redis } = require "../redis"

async = require "async"

class Api extends KeyContainerModel
  @reverseLinkFunction = "linkToApi"
  @reverseUnlinkFunction = "unlinkFromApi"
  @factory = "apifactory"

  isDisabled: ( ) -> @data.disabled

  getCapturePaths: ( cb ) ->
    @smembers [ "meta:capture-paths", @id ], cb

  removeCapturePath: ( path, cb ) ->
    @scard [ "meta:capture-paths", @id ], ( err, length ) =>
      return err if err

      all = []

      # do the delete
      all.push ( cb ) =>
        @srem [ "meta:capture-paths", @id ], path, cb

      # if we're now empty then we need to let redis know. 1 because
      # we've not actually done the del yet.
      if length is 1
        @data.hasCapturePaths = false
        all.push ( cb ) =>
          @app.model( "apifactory" ).hset [ @id ], "hasCapturePaths", false, cb

      return async.series all, cb

  addCapturePath: ( path, cb ) ->
    all = []

    # we also need to make sure the current object knows that there
    # are paths set for fast access in the proxy
    if not @data.hasCapturePaths
      @data.hasCapturePaths = true
      all.push ( cb ) =>
        @app.model( "apifactory" ).hset [ @id ], "hasCapturePaths", true, cb

    all.push ( cb ) => @sadd [ "meta:capture-paths", @id ], path, cb

    return async.parallel all, cb

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
      endPoint:
        type: "string"
        required: true
        docs: "The endpoint for the API. For example; `graph.facebook.com`"
      protocol:
        type: "string"
        enum: [ "https", "http" ]
        default: "http"
        docs: "The protocol for the API, whether or not to use SSL"
      tokenSkewProtectionCount:
        type: "integer"
        default: 3
        docs: "The amount of seconds you allow a valid token to be calculated against, either side of the current second. The higher the number the greater the computational cost."
      apiFormat:
        type: "string"
        enum: [ "json", "xml" ]
        default: "json"
        docs: "The resulting data type of the endpoint. This is redundant at the moment but will eventually support both XML too."
      endPointTimeout:
        type: "integer"
        default: 2
        docs: "Seconds to wait before timing out the connection"
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
        docs: "Set to true to require that SSL certificates be valid."
      sendThroughApiKey:
        type: "boolean"
        default: false
        docs: "If true then the api_key parameter will be passed through in the request."
      sendThroughApiSig:
        type: "boolean"
        default: false
        docs: "If true then the api_sig parameter will be passed through in the request."
      hasCapturePaths:
        type: "boolean"
        default: false
        docs: "When true ApiAxle will parse and capture bits of information about the API being called."
      allowKeylessUse:
        type: "boolean"
        optional: true
        default: false
        docs: "If true then allow for keyless access to this API. Also see keylessQps, keylessQpm, and keylessQpd."
      keylessQps:
        type: "integer"
        optional: false
        default: 2
        docs: "How many queries per second an anonymous key should have."
      keylessQpm:
        type: "integer"
        optional: false
        default: 120
        docs: "How many queries per minute an anonymous key should have."
      keylessQpd:
        type: "integer"
        optional: false
        default: 172800
        docs: "How many queries per day an anonymous key should have."
      qps:
        type: "integer"
        default: 2
        docs: "Number of queries that can be called per second. Set to `-1` for no limit."
      qpm:
        type: "integer"
        default: -1
        docs: "Number of queries that can be called per minute. Set to `-1` for no limit."
      qpd:
        type: "integer"
        default: 172800
        docs: "Number of queries that can be called per day. Set to `-1` for no limit."
      corsEnabled:
        type: "boolean"
        optional: true
        default: false
        docs: "Whether or not you want to enable CORS (http://www.w3.org/TR/cors/) " +
              "support. This enables CORS for all origins and is intended to be simple " +
              "and cover the majority of users. If you need more refined configuration we " +
              "suggest you use something like varnish or nginx to do this. Note that your " +
              "API endpoint should support the OPTIONS method which is often used in 'preflight' " +
              "requests for the XHR object to verify CORS headers. " +
              "When enabled, the following headers will be returned:

              Access-Control-Allow-Origin: *
              Access-Control-Allow-Credentials: true
              Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, PATCH, HEAD
              Access-Control-Allow-Headers: Origin, Accept, Content-Type, X-Requested-With, X-CSRF-Token
              Access-Control-Expose-Headers: content-type, content-length, X-ApiaxleProxy-Qps-Left, X-ApiaxleProxy-Qpm-Left, X-ApiaxleProxy-Qpd-Left
              "
      errorMessage:
        type: "string"
        optional: true
        default: null
        docs: "This gets added as an info property to any errors returned by the proxy for this api."
      additionalHeaders:
        type: "string"
        optional: true
        default: null;
        docs: "Comma-separated list of headers and values to be added, as
               headers, to the endpoint call, 
               e.g., X-SPECIAL=1234,X-VENDOR-TYPE=abc,UNIQUE-VALUE=2js3j"
