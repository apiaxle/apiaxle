async = require "async"

{ ValidationError } = require "../../../../lib/error"
{ FakeAppTest } = require "../../../apiaxle_base"

class exports.KeyTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "keyFactory"

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

  "test #create with an existant api": ( done ) ->
    options =
      endPoint: "api.twitter.com"

    @app.model( "apiFactory" ).create "twitter", options, ( err, newApi ) =>
      @isNull err

      createObj =
        qps: 1
        qpd: 3
        forApis: [ "twitter" ]

      @fixtures.createKey "987654321", createObj, ( err ) =>
        @isNull err

        done 2

  "test #linkToApi and #supportedApis": ( done ) ->
    fixtures =
      api:
        twitter: {}
        facebook: {}
      key:
        1234: {}
        5678: {}

    @fixtures.create fixtures, ( err, [ twitter, facebook, key1, key2 ] ) =>
      @isNull err

      # the fixture creator associates keys with twitter by default
      key1.supportedApis ( err, apis ) =>
        @isNull err
        @deepEqual apis, [ "twitter" ]

        key1.linkToApi "facebook", ( err ) =>
          @isNull err

          key1.supportedApis ( err, apis ) =>
            @isNull err
            @deepEqual apis, [ "twitter", "facebook" ]

            done 6
