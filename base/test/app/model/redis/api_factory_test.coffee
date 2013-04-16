async = require "async"

{ ValidationError } = require "../../../../lib/error"
{ FakeAppTest } = require "../../../apiaxle_base"

class exports.ApiKeyLinkTest extends FakeAppTest
  @empty_db_on_setup = true

  "test deleting unlinks keys": ( done ) ->
    fixture =
      api:
        facebook: {}
        twitter: {}
      key:
        phil: { forApis: [ "facebook", "twitter" ] }
        bob: { forApis: [ "facebook", "twitter" ] }

    @fixtures.create fixture, ( err, [ facebook, twitter, phil, bob ] ) =>
      @isNull err

      facebook.delete ( err ) =>
        @isNull err

        phil.supportedApis ( err, api_list ) =>
          # the keys should no longet know about facebook
          @ok "facebook" not in api_list

          done 3

class exports.ApiTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "apiFactory"

    done()

  "test initialisation": ( done ) ->
    @equal @model.ns, "gk:test:apifactory"

    done 1

  "test #update ing an existing api": ( done ) ->
    fixture =
      api:
        twitter: {}

    @fixtures.create fixture, ( err, [ dbApi ] ) =>
      @isNull err
      @ok dbApi.data.createdAt
      @ok not dbApi.data.updatedAt?

      @fixtures.create fixture, ( err, [ dbApi2 ] ) =>
        @isNull err
        @ok dbApi2.data.updatedAt
        @equal dbApi.data.createdAt, dbApi2.data.createdAt

        done 6

  "test #create with bad structure": ( done ) ->
    newObj =
      apiFormat: "text"

    @model.create "twitter", newObj, ( err ) =>
      @ok err

      done 1

  "test #create with an invalid regex": ( done ) ->
    newObj =
      apiFormat: "xml"
      endPoint: "api.twitter.com"
      extractKeyRegex: "hello( "

    @fixtures.createApi "twitter", newObj, ( err ) =>
      @ok err
      @match err.message, /Invalid regular expression/

      done 2

  "test #create with good structure": ( done ) ->
    newObj =
      apiFormat: "xml"
      endPoint: "api.twitter.com"

    @fixtures.createApi "twitter", newObj, ( err ) =>
      @isNull err

      @model.find [ "twitter" ], ( err, results ) =>
        @isNull err

        @equal results.twitter.data.apiFormat, "xml"
        @ok results.twitter.data.createdAt

        done 4

  "test unlinkkey": ( done ) ->
    fixture =
      api:
        facebook: {}
        twitter: {}
      key:
        1234:
          forApis: [ "facebook", "twitter" ]

    @fixtures.create fixture, ( err, [ dbFacebook, rest... ] ) =>
      @isNull err

      dbFacebook.supportsKey "1234", ( err, supported ) =>
        @isNull err
        @equal supported, true

        dbFacebook.unlinkKeyById "1234", ( err ) =>
          @isNull err

          dbFacebook.supportsKey "1234", ( err, supported ) =>
            @isNull err
            @equal supported, false

            dbFacebook.getKeys 0, 100, ( err, keys ) =>
              @deepEqual keys, []

              done 7

  "test #supportsKey on an API": ( done ) ->
    fixture =
      api:
        facebook: {}
        twitter: {}
      key:
        1234:
          forApis: [ "facebook", "twitter" ]

    @fixtures.create fixture, ( err, objects ) =>
      @isNull err

      @app.model( "apiFactory" ).find [ "facebook" ], ( err, results ) =>
        @isNull err
        @ok results.facebook

        # is supported
        results.facebook.supportsKey "1234", ( err, supported ) =>
          @isNull err
          @equal supported, true

          # isn't supported
          results.facebook.supportsKey "hello", ( err, supported ) =>
            @isNull err
            @equal supported, false

            done 7
