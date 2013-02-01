{ ApiUnknown, ValidationError, KeyNotFoundError } = require "../../../lib/error"
{ Model, Redis } = require "../redis"

validationEnv = require( "schema" )( "apiEnv" )

class Api extends Model
  addKey: ( key, cb ) ->
    @app.model( "keyFactory" ).find key, ( err, dbKey ) =>
      return cb err if err

      if not dbKey
        return cb new KeyNotFoundError "#{ key } doesn't exist."

      dbKey.linkToApi @id, ( err ) =>
        return cb err if err

        multi = @multi()

        # add to the list of all keys
        multi.lpush "#{ @id }:keys", key

        # and add to a quick lookup for the keys
        multi.hset "#{ @id }:keys-lookup", key, 1

        multi.exec cb

  # TODO: implement this
  deleteKey: ( key, cb ) ->
    # call `dbKey.unlinkFromApi`

  getKeys: ( start, stop, cb ) ->
    @lrange "#{ @id }:keys", start, stop, cb

  supportsKey: ( key, cb ) ->
    @hexists "#{ @id }:keys-lookup", key, ( err, exists ) ->
      return cb err if err

      if exists is 0
        return cb null, false

      return cb null, true

class exports.ApiFactory extends Redis
  @instantiateOnStartup = true
  @returns   = Api
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
        pre: ( value ) ->
          try
            new RegExp( value )
            return value
          catch err
            throw new ValidationError( err.message )
