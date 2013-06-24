_ = require "lodash"

{ StatsController,
  ApiaxleController,
  ListController } = require "../controller"
{ AlreadyExists } = require "../../../lib/error"

class exports.CreateKeyring extends ApiaxleController
  @verb = "post"

  desc: -> "Provision a new KEYRING."

  docs: ->
    {}=
      title: "Provision a new KEYRING."
      input: @app.model( 'keyringfactory' ).constructor.structure.properties
      response: "The inserted structure (including the new timestamp fields)."

  middleware: -> [ @mwContentTypeRequired(),
                   @mwValidateQueryParams(),
                   @mwKeyringDetails() ]

  path: -> "/v1/keyring/:keyring"

  execute: ( req, res, next ) ->
    # error if it exists
    if req.keyring?
      return next new AlreadyExists "'#{ req.keyring.id }' already exists."

    @app.model( "keyringfactory" ).create req.params.keyring, req.body, ( err, newObj ) =>
      return next err if err
      return @json res, newObj.data

class exports.ViewKeyring extends ApiaxleController
  @verb = "get"

  desc: -> "Get the definition for an KEYRING."

  docs: ->
    {}=
      title: "Get the definition for an KEYRING."
      response: "The KEYRING structure (including the timestamp fields)."

  middleware: -> [ @mwValidateQueryParams(),
                   @mwKeyringDetails( valid_keyring_required=true ) ]

  path: -> "/v1/keyring/:keyring"

  execute: ( req, res, next ) ->
    @json res, req.keyring.data

class exports.DeleteKeyring extends ApiaxleController
  @verb = "delete"

  desc: -> "Delete an KEYRING."

  docs: ->
    {}=
      title: "Delete an KEYRING."
      response: "TRUE on success"

  middleware: -> [ @mwValidateQueryParams(),
                   @mwKeyringDetails( valid_keyring_required=true ) ]

  path: -> "/v1/keyring/:keyring"

  execute: ( req, res, next ) ->
    model = @app.model "keyringfactory"

    model.del req.params.keyring, ( err, newKeyring ) =>
      return next err if err

      @json res, true

class exports.ModifyKeyring extends ApiaxleController
  @verb = "put"

  desc: -> "Update an KEYRING."

  docs: ->
    {}=
      title: "Update an KEYRING."
      input: @app.model( "keyringfactory" ).constructor.structure.properties
      response: "The merged structure (including the timestamp fields)."

  middleware: -> [
    @mwContentTypeRequired( ),
    @mwKeyringDetails( valid_keyring_required=true ),
    @mwValidateQueryParams()
  ]

  path: -> "/v1/keyring/:keyring"

  execute: ( req, res, next ) ->
    req.keyring.update req.body, ( err, new_keyring, old_keyring ) =>
      return next err if err
      return @json res,
        new: new_keyring
        old: old_keyring

class exports.ListKeyringKeys extends ListController
  @verb = "get"

  path: -> "/v1/keyring/:keyring/keys"

  desc: -> "List keys belonging to an KEYRING."

  queryParams: ->
    params =
      type: "object"
      additionalProperties: false
      properties:
        from:
          type: "integer"
          default: 0
          docs: "The index of the first key you want to
                 see. Starts at zero."
        to:
          type: "integer"
          default: 10
          docs: "The index of the last key you want to see. Starts at
                 zero."
        resolve:
          type: "boolean"
          default: false
          docs: "If set to `true` then the details concerning the
                 listed keys will also be printed. Be aware that this
                 will come with a minor performace hit."

  docs: ->
    {}=
      title: "List keys belonging to an KEYRING."
      response: """
        With <strong>resolve</strong>: An object mapping each key to the
        corresponding details.<br />
        Without <strong>resolve</strong>: An array with 1 key per entry
      """

  modelName: -> "keyringfactory"

  middleware: -> [ @mwValidateQueryParams(),
                   @mwKeyringDetails( @app ) ]

  execute: ( req, res, next ) ->
    { from, to } = req.query

    req.keyring.getKeys from, to, ( err, keys ) =>
      return next err if err
      return @json res, keys if not req.query.resolve

      @resolve @app.model( "keyfactory" ), keys, ( err, results ) =>
        return next err if err
        return @json res, results


class exports.UnlinkKeyToKeyring extends ApiaxleController
  @verb = "put"

  desc: -> "Disassociate a key with a KEYRING."

  docs: ->
    {}=
      title: "Disassociate a key with a KEYRING."
      response: "The unlinked key details."

  middleware: -> [ @mwKeyringDetails( valid_keyring_required=true ),
                   @mwKeyDetails( valid_key_required=true ),
                   @mwValidateQueryParams() ]

  path: -> "/v1/keyring/:keyring/unlinkkey/:key"

  execute: ( req, res, next ) ->
    req.keyring.unlinkKeyById req.key.id, ( err ) =>
      return next err if err

      @json res, req.key.data

class exports.LinkKeyToKeyring extends ApiaxleController
  @verb = "put"

  desc: -> "Associate a key with a KEYRING."

  docs: ->
    {}=
      title: "Associate a key with a KEYRING."
      description: """
        The key must already exist and will not be modified by this
        operation.
      """
      response: "The linked key details."

  middleware: -> [ @mwKeyringDetails( valid_keyring_required=true ),
                   @mwKeyDetails( valid_key_required=true ),
                   @mwValidateQueryParams() ]

  path: -> "/v1/keyring/:keyring/linkkey/:key"

  execute: ( req, res, next ) ->
    req.keyring.linkKey req.key.id, ( err ) =>
      return next err if err

      @json res, req.key.data

class exports.ViewAllStatsForKeyring extends StatsController
  @verb = "get"

  desc: -> "Get stats for an keyring."

  queryParams: ->
    current = super()

    # extends the base class queryParams
    _.extend current.properties,
      forkey:
        type: "string"
        optional: true
        docs: "Narrow results down to all statistics for the specified
               key."
      forapi:
        type: "string"
        optional: true
        docs: "Narrow results down to all statistics for the specified
               api."

    return current

  docs: ->
    {}=
      verb: "GET"
      title: "Get stats for an keyring"
      response: """
        Object where the keys represent the cache status (cached, uncached or
        error), each containing an object with response codes or error name,
        these in turn contain objects with timestamp:count
      """

  middleware: -> [ @mwKeyringDetails( @app ),
                   @mwValidateQueryParams() ]

  path: -> "/v1/keyring/:keyring/stats"

  execute: ( req, res, next ) ->
    axle_type      = "keyring"
    redis_key_part = [ req.keyring.id ]

    # narrow down to a particular key
    if for_key = req.query.forkey
      axle_type      = "keyring-key"
      redis_key_part = [ req.keyring.id, for_key ]

    # narrow down to a particular api
    if for_api = req.query.forapi
      axle_type      = "keyring-api"
      redis_key_part = [ req.keyring.id, for_api ]

    @getStatsRange req, axle_type, redis_key_part, ( err, results ) =>
      return next err if err
      return @json res, results
