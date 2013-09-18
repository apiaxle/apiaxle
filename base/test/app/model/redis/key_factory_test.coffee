# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
async = require "async"

{ ValidationError } = require "../../../../lib/error"
{ FakeAppTest } = require "../../../apiaxle_base"

class exports.KeyTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "keyfactory"

    done()

  "test initialisation": ( done ) ->
    @ok @app
    @ok @model

    @equal @model.ns, "gk:test:key"

    done 3

  "test #create with bad structure": ( done ) ->
    createObj =
      qpd: "text"

    @fixtures.createKey "987654321", createObj, ( err ) =>
      @ok err

      done 1

  "test #create with non-existent api": ( done ) ->
    createObj =
      qps: 1
      qpd: 3
      forApis: [ "twitter" ]

    @fixtures.createKey "987654321", createObj, ( err ) =>
      @ok err
      @equal err.message, "API 'twitter' doesn't exist."

      done 2

  "test #create with an existing api": ( done ) ->
    options =
      endPoint: "api.twitter.com"

    @app.model( "apifactory" ).create "twitter", options, ( err, newApi ) =>
      @isUndefined err?.message

      createObj =
        qps: 1
        qpd: 3
        forApis: [ "twitter" ]

      @fixtures.createKey "987654321", createObj, ( err ) =>
        @ok not err

        done 2

  "test #updating a key": ( done ) ->
    createObj =
      qps: 1
      qpd: 3

    @fixtures.createKey "987654321", createObj, ( err, dbKey ) =>
      @ok not err
      @ok dbKey.data

      dbKey.update sharedSecret: "blah", ( err ) =>
        @ok not err

        @app.model( "keyfactory" ).find [ "987654321" ], ( err, results ) =>
          @ok not err
          @equal results["987654321"].data.sharedSecret, "blah"

          done 5

  "test #linkToApi and #supportedApis": ( done ) ->
    fixtures =
      api:
        twitter:
          endPoint: "twitter.example.com"
        facebook:
          endPoint: "facebook.example.com"
        hello:
          endPoint: "hello.example.com"
      key:
        1234:
          forApis: [ "twitter" ]
        5678: {}

    @fixtures.create fixtures, ( err, [ twitter, facebook, hello, key1, key2 ] ) =>
      @ok not err

      # the fixture creator associates keys with twitter by default
      key1.supportedApis ( err, apis ) =>
        @ok not err
        @deepEqual apis, [ "twitter" ]

        key1.linkToApi "facebook", ( err ) =>
          @ok not err

          key1.supportedApis ( err, apis ) =>
            @ok not err
            @deepEqual apis, [ "twitter", "facebook" ]

            key1.isLinkedToApi "facebook", ( err, res ) =>
              @equal res, true

              key1.isLinkedToApi "hello", ( err, res ) =>
                @equal res, false

                done 8

class exports.KeyApiLinkTest extends FakeAppTest
  @empty_db_on_setup = true

  "test deleting keys unlinks them from APIs": ( done ) ->
    fixture =
      api:
        facebook:
          endPoint: "example.com"
        twitter:
          endPoint: "example.com"
      key:
        phil: { forApis: [ "facebook", "twitter" ] }
        bob: { forApis: [ "facebook", "twitter" ] }

    @fixtures.create fixture, ( err, [ facebook, twitter, phil, bob ] ) =>
      @ok not err

      phil.delete ( err ) =>
        @ok not err

        facebook.getKeys 0, 100, ( err, key_list ) =>
          @ok not err

          # facebook should no longer know of phil
          @ok "phil" not in key_list

          done 4
