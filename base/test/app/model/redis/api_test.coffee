async = require "async"

{ ValidationError } = require "../../../../lib/error"
{ FakeAppTest } = require "../../../apiaxle_base"

class exports.ApiTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @application.model "api"

    done()

  "test initialisation": ( done ) ->
    @ok @application
    @ok @model

    @equal @model.ns, "gk:test:api"

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

    @model.create "twitter", newObj, ( err ) =>
      @ok err
      @match err.message, /Invalid regular expression/

      done 2

  "test #create with good structure": ( done ) ->
    newObj =
      apiFormat: "xml"
      endPoint: "api.twitter.com"

    @model.create "twitter", newObj, ( err ) =>
      @isNull err

      @model.find "twitter", ( err, details ) =>
        @isNull err

        @equal details.apiFormat, "xml"
        @ok details.createdAt

        done 4
