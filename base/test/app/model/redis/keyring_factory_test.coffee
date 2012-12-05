async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"

class exports.KeyringFactoryTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @application.model "keyringFactory"

    done()

  "test initialisation": ( done ) ->
    @ok @application
    @ok @model

    @equal @model.ns, "gk:test:keyringfactory"

    done 3

  "test creating a keyring": ( done ) ->
    @model.create "keyring_one", {}, ( err, keyring ) =>
      @isNull err
      @ok keyring

      @model.find "keyring_one", ( err, keyring ) =>
        @isNull err
        @equal keyring.id, "keyring_one"

        done 4

  "test adding an unknown key to a keyring": ( done ) ->
    @fixtures.createKeyring ( err, keyring ) =>
      @isNull err

      # 1234 doesn't exist
      keyring.addKey "1234", ( err, key ) =>
        @ok err
        @match err.message, /Key 1234 not found/
  
        done 2

  "test adding a key to the keyring": ( done ) ->
    @fixtures.createApiAndKey "facebook", {}, "1234", {}, ( err ) =>
      @isNull err

      @fixtures.createKeyring ( err, keyring ) =>
        @isNull err

        keyring.addKey "1234", ( err, key ) =>
          @isNull err
          @ok key
          @equal key.id, "1234"

          done 5
