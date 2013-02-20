_     = require "underscore"
async = require "async"

{ Redis, Model } = require "../redis"
{ ValidationError } = require "../../../lib/error"

class Key extends Model
  linkToApi: ( apiName, cb ) -> @hset "#{ @id }-apis", apiName, 1, cb
  supportedApis: ( cb ) -> @hkeys "#{ @id }-apis", cb
  unlinkFromApi: ( apiName, cb ) -> @hdel "#{ @id }-apis", apiName, cb

  linkToKeyring: ( krName, cb ) -> @hset "#{ @id }-keyrings", krName, 1, cb
  supportedKeyrings: ( cb ) -> @hkeys "#{ @id }-keyrings", cb
  unlinkFromKeyring: ( krName, cb ) -> @hdel "#{ @id }-keyrings", krName, cb

class exports.KeyFactory extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "key"
  @returns      = Key

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
      sharedSecret:
        type: "string"
        optional: true
        docs: "A shared secret which is used when signing a call to the api."
      qpd:
        type: "integer"
        default: 172800
        docs: "Number of queries that can be called per day. Set to `-1` for no limit."
      qps:
        type: "integer"
        default: 2
        docs: "Number of queries that can be called per second. Set to `-1` for no limit."
      forApis:
        optional: true
        type: "array"
        docs: "Names of the Apis that this key belongs to."

  _verifyApisExist: ( apis, cb ) ->
    allKeyExistsChecks = []

    for api in apis
      do( api ) =>
        allKeyExistsChecks.push ( cb ) =>
          @app.model( "apiFactory" ).find api, ( err, dbApi ) ->
            return cb err if err

            if not dbApi
              return cb new ValidationError "API '#{ api }' doesn't exist."

            return cb null, dbApi

    async.parallel allKeyExistsChecks, cb

  _linkKeyToApis: ( dbApis, dbKey, cb ) ->
    allKeysLink = []

    for api in dbApis
      do( api ) ->
        allKeysLink.push ( cb ) ->
          api.linkKey dbKey.id, ( err ) ->
            return cb err if err
            return cb null, dbKey

    async.parallel allKeysLink, cb

  create: ( id, details, cb ) ->
    # if there isn't a forApis field then `super` will take care of
    # that
    if not details?.forApis?
      return super

    # grab the apis this should belong to and then delete the key pair
    # because we don't actually want to store it.
    forApis = details.forApis
    delete details.forApis

    # first we need to make sure all of the keys actually
    # exist. #create should behave atomically if possible
    @_verifyApisExist forApis, ( err, dbApis ) =>
      return cb err if err

      # this creates the actual key
      @callConstructor id, details, ( err, dbKey ) =>
        return cb err if err

        @_linkKeyToApis dbApis, dbKey, ( err ) =>
          return cb err if err
          return cb null, dbKey
