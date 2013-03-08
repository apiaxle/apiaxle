async = require "async"

{ FakeAppTest } = require "../../../apiaxle-base"

class exports.ApiTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "cache"

    done()

  "test initialisation": ( done ) ->
    @ok @app
    @ok @model

    @equal @model.ns, "gk:test:cache"

    done 3

  "test adding a page": ( done ) ->
    @model.add "29834IUHOIUHOIHO234", 20, 200, "application/json", "hello", ( err ) =>
      @isNull err

      @model.ttl "29834IUHOIUHOIHO234", ( err, ttl ) =>
        @isNull err
        @ok ( ttl <= 20 and ttl > 0 )

        @model.get "29834IUHOIUHOIHO234", ( err, status, contentType, content ) =>
          @isNull err
          @equal contentType, "application/json"
          @equal content, "hello"
          @equal status, 200

          done 7
