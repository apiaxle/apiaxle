# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"

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
      @ok not err

      @model.ttl "29834IUHOIUHOIHO234", ( err, ttl ) =>
        @ok not err
        @ok ( ttl <= 20 and ttl > 0 )

        @model.get "29834IUHOIUHOIHO234", ( err, status, contentType, content ) =>
          @ok not err
          @equal contentType, "application/json"
          @equal content, "hello"
          @equal status, 200

          done 7
