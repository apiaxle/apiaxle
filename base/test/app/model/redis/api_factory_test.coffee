async = require "async"

{ ValidationError } = require "../../../../lib/error"
{ FakeAppTest } = require "../../../apiaxle_base"

class exports.ApiTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "apiFactory"

    done()

  "test initialisation": ( done ) ->
    @ok @app
    @ok @model

    @equal @model.ns, "gk:test:apifactory"

    done 3

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
      extractKeyRegex: "hello("

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

      @model.find "twitter", ( err, api ) =>
        @isNull err

        @equal api.data.apiFormat, "xml"
        @ok api.data.createdAt

        done 4

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

      @app.model( "apiFactory" ).find "facebook", ( err, api ) =>
        @isNull err
        @ok api

        # is supported
        api.supportsKey "1234", ( err, supported ) =>
          @isNull err
          @equal supported, true

          # isn't supported
          api.supportsKey "hello", ( err, supported ) =>
            @isNull err
            @equal supported, false

            done 7
