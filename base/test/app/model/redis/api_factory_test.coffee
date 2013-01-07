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

  # for an explanation of what this is for see github issue 32
  "test creating an api called 'all' should be fine": ( done ) ->
    fixture =
      api:
        twitter: {}
      key:
        1234: {}
        5678: {}

    model = @app.model( "apiFactory" )

    # create the api/keys
    @fixtures.create fixture, ( err ) =>
      @isNull err

      # now create a new api called 'all'
      @fixtures.createApi "all", ( err ) =>
        @isNull err

        # finding 'all' should return the details we expect
        model.find "all", ( err, dbApi ) =>
          @isNull err
          @ok dbApi

          done 5
