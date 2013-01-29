_     = require "underscore"
async = require "async"

{ Redis, Model } = require "../redis"
{ ValidationError } = require "../../../lib/error"

validationEnv = require( "schema" )( "keyEnv" )

class Key extends Model

class exports.KeyFactory extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "key"
  @returns      = Key

  @structure = validationEnv.Schema.create
    type: "object"
    additionalProperties: false
    properties:
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

  create: ( id, details, cb ) ->
    # if there isn't a forApis field then `super` will take care of
    # that
    if not details?.forApis?
      return super

    allKeyExistsChecks = []

    # grab the apis this should belong to and then delete the key pair
    # because we don't actually want to store it.
    forApis = details.forApis
    delete details.forApis

    # first we need to make sure all of the keys actually
    # exist. #create should behave atomically if possible
    for api in forApis
      do( api ) =>
        allKeyExistsChecks.push ( cb ) =>
          @app.model( "apiFactory" ).find api, ( err, dbApi ) ->
            return cb err if err

            if not dbApi
              return cb new ValidationError "API '#{ api }' doesn't exist."

            return cb null, dbApi

    async.parallel allKeyExistsChecks, ( err, dbApis ) =>
      return cb err if err

      # now that we know the apis exist, link the keys to them
      allKeysCreate = []

      for api in dbApis
        do( api ) ->
          allKeysCreate.push ( cb ) ->
            api.addKey id, ( err, dbKey ) ->
              return cb err if err
              return cb null, dbKey

      async.parallel allKeysCreate, ( err, dbKeys ) =>
        return cb err if err

        return @constructor.__super__.create.apply @, [ id, details, cb ]
