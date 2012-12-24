_ = require "underscore"

{ ApiaxleController, ListController } = require "../controller"
{ AlreadyExists } = require "../../../lib/error"

class exports.CreateKeyring extends ApiaxleController
  @verb = "post"

  desc: -> "Provision a new KEYRING."

  docs: ->
    """
    ### JSON fields supported

    #{ @app.model( 'keyringFactory' ).getValidationDocs() }

    ### Returns

    * The inserted structure (including the new timestamp fields).
    """

  middleware: -> [ @mwKeyringDetails( ) ]

  path: -> "/v1/keyring/:keyring"

  execute: ( req, res, next ) ->
    # error if it exists
    if req.keyring?
      return next new AlreadyExists "#{ keyring } already exists."

    model = @app.model "keyringFactory"
    model.create req.params.keyring, req.body, ( err, newObj ) =>
      return next err if err

      @json res, newObj.data

class exports.ViewKeyring extends ApiaxleController
  @verb = "get"

  desc: -> "Get the definition for an KEYRING."

  docs: ->
    """
    ### Returns

    * The KEYRING structure (including the timestamp fields).
    """

  middleware: -> [ @mwKeyringDetails( valid_keyring_required=true ) ]

  path: -> "/v1/keyring/:keyring"

  execute: ( req, res, next ) ->
    @json res, req.keyring.data

class exports.DeleteKeyring extends ApiaxleController
  @verb = "delete"

  desc: -> "Delete an KEYRING."

  docs: ->
    """
    ### Returns

    * `true` on success.
    """

  middleware: -> [ @mwKeyringDetails( valid_keyring_required=true ) ]

  path: -> "/v1/keyring/:keyring"

  execute: ( req, res, next ) ->
    model = @app.model "keyringFactory"

    model.del req.params.keyring, ( err, newKeyring ) =>
      return next err if err

      @json res, true

class exports.ModifyKeyring extends ApiaxleController
  @verb = "put"

  desc: -> "Update an KEYRING."

  docs: ->
    """Will merge fields you pass in.

    ### JSON fields supported

    #{ @app.model( 'keyringFactory' ).getValidationDocs() }

    ### Returns

    * The merged structure (including the timestamp fields).
    """

  middleware: -> [
    @mwContentTypeRequired( ),
    @mwKeyringDetails( valid_keyring_required=true )
  ]

  path: -> "/v1/keyring/:keyring"

  execute: ( req, res, next ) ->
    model = @app.model "keyringFactory"

    # modify the old keyring struct
    newData = _.extend req.keyring.data, req.body

    # validate it
    model.validate newData, ( err, instance ) =>
      return next err if err

      # re-apply it to the db
      model.create req.params.keyring, instance, ( err, newKeyring ) =>
        return next err if err

        @json res, newKeyring.data

class exports.ListKeyrings extends ListController
  @verb = "get"

  path: -> "/v1/keyrings"

  desc: -> "List all KEYRINGs."

  docs: ->
    """
    ### Supported query params

    * from: Integer for the index of the first keyring you want to
      see. Starts at zero.
    * to: Integer for the index of the last keyring you want to
      see. Starts at zero.
    * resolve: if set to `true` then the details concerning the listed
      keyrings  will also be printed. Be aware that this will come with a
      minor performace hit.

    ### Returns

    * Without `resolve` the result will be an array with one keyring per
      entry.
    * If `resolve` is passed then results will be an object with the
      keyring name as the keyring and the details as the value.
    """

  modelName: -> "keyringFactory"

class exports.ListKeyringKeys extends ListController
  @verb = "get"

  path: -> "/v1/keyring/:keyring/keys"

  desc: -> "List keys belonging to an KEYRING."

  docs: ->
    """
    ### Supported query params

    * from: Integer for the index of the first key you want to
      see. Starts at zero.
    * to: Integer for the index of the last key you want to
      see. Starts at zero.
    * resolve: if set to `true` then the details concerning the listed
      keys will also be printed. Be aware that this will come with a
      minor performace hit.

    ### Returns

    * Without `resolve` the result will be an array with one key per
      entry.
    * If `resolve` is passed then results will be an object with the
      key name as the key and the details as the value.
    """

  modelName: -> "keyFactory"

  middleware: -> [ @mwKeyringDetails( @app ) ]

class exports.AddKeyringKey extends ApiaxleController
  @verb = "post"

  path: -> "/v1/keyring/:keyring/key/:key"

  desc: -> "Add existing KEY to existing KEYRING."

  docs: ->
    """
    ### Returns

    * `true` if the operation is successful.
    """

  middleware: -> [ @mwKeyringDetails( valid_keyring_required=true ),
                   @mwKeyDetails( valid_key_required=true ) ]

  execute: ( req, res, next ) ->
    req.keyring.addKey req.key.id, ( err ) =>
      return next err if err

      @json res, true

class exports.DelKeyringKey extends ApiaxleController
  @verb = "post"

  path: -> "/v1/keyring/:keyring/key/:key"

  desc: -> "Delete and existing KEY from an existing KEYRING."

  docs: ->
    """
    ### Returns

    * `true` if the operation is successful.
    """

  middleware: -> [ @mwKeyringDetails( valid_keyring_required=true ),
                   @mwKeyDetails( valid_key_required=true ) ]

  execute: ( req, res, next ) ->
    req.keyring.delKey req.key.id, ( err ) =>
      return next err if err

      @json res, true
