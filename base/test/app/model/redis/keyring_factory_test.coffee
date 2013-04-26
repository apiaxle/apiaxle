async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"

class exports.KeyringFactoryTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "keyringfactory"

    done()

  "test initialisation": ( done ) ->
    @equal @model.ns, "gk:test:keyringfactory"

    done 1

  "test #update ing an existing keyring": ( done ) ->
    fixture =
      keyring:
        blah: {}

    @fixtures.create fixture, ( err, [ dbKeyring ] ) =>
      @ok not err
      @ok dbKeyring.data.createdAt
      @ok not dbKeyring.data.updatedAt?

      @fixtures.create fixture, ( err, [ dbKeyring2 ] ) =>
        @ok not err
        @ok dbKeyring2.data.updatedAt
        @equal dbKeyring.data.createdAt, dbKeyring2.data.createdAt

        done 6

  "test creating a keyring": ( done ) ->
    @model.create "keyring_one", {}, ( err, keyring ) =>
      @ok not err
      @ok keyring

      @model.find [ "keyring_one" ], ( err, results ) =>
        @ok not err
        @equal results.keyring_one.id, "keyring_one"

        done 4

  "test adding an unknown key to a keyring fails": ( done ) ->
    @fixtures.createKeyring "kr1", {}, ( err, keyring ) =>
      @ok not err

      # 1234 doesn't exist
      keyring.linkKey "1234", ( err, key ) =>
        @ok err
        @match err.message, /1234 doesn't exist/ #'

        done 3

  "test adding a key to the keyring": ( done ) ->
    fixture =
      api:
        facebook:
          endPoint: "example.com"
      key:
        1234:
          forApis: [ "facebook" ]

    @fixtures.create fixture, ( err ) =>
      @ok not err

      @fixtures.createKeyring "kr1", {}, ( err, keyring ) =>
        @ok not err

        keyring.linkKey "1234", ( err, key ) =>
          @ok not err
          @ok key
          @equal key.id, "1234"

          done 5

  "test deleting keys from a ring": ( done ) ->
    fixture =
      api:
        twitter:
          endPoint: "example.com"
      key:
        1234: {}
        5678: {}
      keyring:
        ring2: {}

    @fixtures.create fixture, ( err, [ api, key1, key2, keyring ] ) =>
      @ok not err

      keyring.linkKey key1.id, ( err ) =>
        @ok not err

        keyring.linkKey key2.id, ( err ) =>
          @ok not err

          keyring.getKeys 0, 10, ( err, keys ) =>
            @ok not err
            @deepEqual keys, [ key2.id, key1.id ]

            keyring.unlinkKeyById key1.id, ( err, result ) =>
              @ok not err

              keyring.getKeys 0, 10, ( err, keys ) =>
                @ok not err
                @deepEqual keys, [ key2.id ]

                done 8

  "test getting keys from a ring": ( done ) ->
    all = []

    all.push ( cb ) =>
      @fixtures.createApi "twitter", endPoint: "twitter.example.com", cb

    @fixtures.createKeyring "kr1", {}, ( err, keyring ) =>
      for i in [ 1..9 ]
        do( i ) =>
          all.push ( cb ) =>
            # create a bunch of keys
            @fixtures.createKey "key#{ i }", {}, ( err, key ) =>
              @ok not err
              @ok key

              # add the new key
              keyring.linkKey key.id, ( err, added_key ) =>
                @ok not err
                @ok added_key

                @equal added_key.id, key.id

                return cb null, key.id

      async.series all, ( err, [ api, added_keys... ] ) =>
        @ok not err

        keyring.getKeys 0, 1000, ( err, keys ) =>
          @ok not err
          @equal keys.length, 9
          @deepEqual keys, added_keys.reverse()

          done 49
