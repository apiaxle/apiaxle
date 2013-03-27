_     = require "underscore"
async = require "async"

{ Redis, Model } = require "../redis"
{ ValidationError } = require "../../../lib/error"

class Key extends Model
  @factory = "keyFactory"

  linkToApi: ( apiName, cb ) -> @hset "#{ @id }-apis", apiName, 1, cb
  supportedApis: ( cb ) -> @hkeys "#{ @id }-apis", cb
  unlinkFromApi: ( apiName, cb ) -> @hdel "#{ @id }-apis", apiName, cb

  linkToKeyring: ( krName, cb ) -> @hset "#{ @id }-keyrings", krName, 1, cb
  supportedKeyrings: ( cb ) -> @hkeys "#{ @id }-keyrings", cb
  unlinkFromKeyring: ( krName, cb ) -> @hdel "#{ @id }-keyrings", krName, cb

  isDisabled: ( ) -> @data.disabled

  delete: ( cb ) ->
    @supportedApis ( err, api_list ) =>
      return cb err if err

      unlink_from_api = []

      # find each of the apis and unlink ourselves from it
      for api in api_list
        do( api ) =>
          unlink_from_api.push ( cb ) =>
            @app.model( "apiFactory" ).find api, ( err, dbApi ) =>
              return cb err if err
              return dbApi.unlinkKey @, cb

      async.parallel unlink_from_api, ( err ) =>
        return cb err if err
        return Key.__super__.delete.apply @, [ cb ]

  update: ( new_data, cb ) ->
    # if someone has upped the qpd then we need to take account as
    # their current qpd counter might be at a value below what they
    # would now be allowed
    limits_model = @app.model "apiLimits"
    redis_key_name = limits_model.qpdKey @id

    all_actions = []
    limits_model.get redis_key_name, ( err, current_qpd ) =>
      return cb err if err

      # string from redis
      current_qpd = parseInt current_qpd

      # if the qpd changes we might need to take note
      if new_data.qpd isnt @data.qpd
        all_actions.push ( cb ) =>
          # now find out how many of their current qpd they've used.
          used = ( @data.qpd - current_qpd )
          limits_model.updateQpValue redis_key_name, ( new_data.qpd - used ), cb

      # run the original update
      all_actions.push ( cb ) =>
        @constructor.__super__.update.apply @, [ new_data, cb ]

      async.parallel all_actions, cb

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
      disabled:
        type: "boolean"
        default: false
        docs: "Disable this API causing errors when it's hit."

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
