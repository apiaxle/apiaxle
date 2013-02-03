async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"

class exports.KeyringFactoryTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "keyringFactory"

    done()

  "test initialisation": ( done ) ->
    @ok @app
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
        @match err.message, /Key '1234' not found/

        done 3

  "test adding a key to the keyring": ( done ) ->
    fixture =
      api:
        facebook: {}
      key:
        1234:
          forApis: [ "facebook" ]

    @fixtures.create fixture, ( err ) =>
      @isNull err

      @fixtures.createKeyring ( err, keyring ) =>
        @isNull err

        keyring.addKey "1234", ( err, key ) =>
          @isNull err
          @ok key
          @equal key.id, "1234"

          done 5

  "test deleting keys from a ring": ( done ) ->
    fixture =
      api:
        twitter: {}
      key:
        1234: {}
        5678: {}
      keyring:
        ring2: {}

    @fixtures.create fixture, ( err, [ api, key1, key2, keyring ] ) =>
      @isNull err

      keyring.addKey key1.id, ( err ) =>
        @isNull err

        keyring.addKey key2.id, ( err ) =>
          @isNull err

          keyring.getKeys 0, 10, ( err, keys ) =>
            @isNull err
            @deepEqual keys, [ key2.id, key1.id ]

            keyring.delKey key1.id, ( err, result ) =>
              @isNull err

              keyring.getKeys 0, 10, ( err, keys ) =>
                @isNull err
                @deepEqual keys, [ key2.id ]

                done 8

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
