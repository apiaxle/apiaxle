async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"

class exports.ApiTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @application.model "cache"

    done()

  "test initialisation": ( done ) ->
    @ok @application
    @ok @model

    @equal @model.ns, "gk:test:cache"

    done 3

  "test adding a page": ( done ) ->
    @model.add "29834IUHOIUHOIHO234", 20, "hello", ( err ) =>
      @isNull err

      @model.ttl "29834IUHOIUHOIHO234", ( err, ttl ) =>
        @isNull err
        @ok ( ttl <= 20 and ttl > 0 )

        @model.get "29834IUHOIUHOIHO234", ( err, status, content ) =>
          @isNull err
          @equal content, "hello"

          done 5
