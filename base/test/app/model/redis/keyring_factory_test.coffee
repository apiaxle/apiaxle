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

  "test adding an unknown key to a keyring fails": ( done ) ->
    @fixtures.createKeyring ( err, keyring ) =>
      @isNull err

      # 1234 doesn't exist
      keyring.addKey "1234", ( err, key ) =>
        @ok err
        @match err.message, /Key 1234 not found/
  
        done 3

  "test adding a key to the keyring": ( done ) ->
    fixture =
      api:
        facebook: {}
      key:
        1234:
          forApi: "facebook"

    @fixtures.create fixture, ( err ) =>
      @isNull err

      @fixtures.createKeyring ( err, keyring ) =>
        @isNull err

        keyring.addKey "1234", ( err, key ) =>
          @isNull err
          @ok key
          @equal key.id, "1234"

          done 5

  "test getting keys from a ring": ( done ) ->
    all = []

    all.push ( cb ) => @fixtures.createApi "twitter", cb
    @fixtures.createKeyring ( err, keyring ) =>
      for i in [ 1..9 ]
        all.push ( cb ) =>
          # create a bunch of keys
          @fixtures.createKey ( err, key ) =>
            @isNull err
            @ok key

            # add the new key
            keyring.addKey key.id, ( err, added_key ) =>
              @isNull err
              @ok added_key

              @equal added_key.id, key.id

              return cb null, key.id

      async.series all, ( err, [ api, added_keys... ] ) =>
        @isNull err

        keyring.getKeys 0, 1000, ( err, keys ) =>
          @isNull err
          @equal keys.length, 9
          @deepEqual keys, added_keys.reverse()
          
          done 49
