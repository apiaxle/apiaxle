# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
async = require "async"

{ FakeAppTest } = require "../../apiaxle_base"
{ Redis }       = require "../../../app/model/redis"

class TestModel extends Redis
  @structure =
    type: "object"
    additionalProperties: false
    properties:
      one:
        type: "integer"

class exports.RedisTest extends FakeAppTest
  @empty_db_on_setup = true

  "test finding an object without @returns set": ( done ) ->
    @ok test_model = new TestModel @app

    test_model.create "hello", { one: 1 }, ( err, newObject ) =>
      @ok not err
      @equal newObject.one, 1

      test_model.find [ "hello" ], ( err, results ) =>
        @ok not err
        @ok results

        @equal results.hello.one, 1

        done 6

  "test multi incr/decr": ( done ) ->
    @ok model = @app.model "counters"
    @ok multi = model.multi()

    model.set [ "test" ], 20, ( err, value ) =>
      @ok not err

      multi.decr [ "test" ]
      multi.incr [ "test" ]
      multi.incr [ "test" ]

      multi.exec ( err, results ) =>
        @ok not err
        @deepEqual results, [ 19, 20, 21 ]

        model.get [ "test" ], ( err, value ) =>
          @equal value, 21

          done 6

  "test multi set/get": ( done ) ->
    @ok model = @app.model "counters"
    @ok multi = model.multi()

    multi.set [ "test" ], 1

    multi.exec ( err, results ) =>
      # check the key was written with the correct namespace
      model.get [ "test" ], ( err, value ) =>
        @ok not err
        @equal value, 1

        done 4
  "test creating ids with : in them should be fine": ( done ) ->
    model = new TestModel @app

    @equal model.escapeId( "hello:world" ), "hello\\:world"
    @equal model.escapeId( "meta:data:world" ), "meta\\:data\\:world"

    model.create "this:is:an:id", { one: 2 }, ( err ) =>
      @ok not err

      model.find [ "this:is:an:id" ], ( err, results ) =>
        @ok not err
        @ok results["this:is:an:id"]
        @equal results["this:is:an:id"].one, 2

        done 6

  # for an explanation of what this is for see github issue 32
  "test creating an api called 'all' should be fine": ( done ) ->
    model = new TestModel @app

    # now create a new api called 'all'
    model.create "all", { one: 1 }, ( err ) =>
      @ok not err

      # finding 'all' should return the details we expect
      model.find [ "all" ], ( err, results ) =>
        @ok not err
        @ok results.all
        @equal results.all.one, 1

        done 4
