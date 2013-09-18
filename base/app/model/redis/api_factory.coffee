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
