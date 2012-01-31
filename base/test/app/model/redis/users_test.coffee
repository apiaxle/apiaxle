async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"

class exports.UsersTest extends FakeAppTest
  @empty_db_on_setup = true

  "test initialisation": ( done ) ->
    @ok @application
    @ok @model = @application.model "users"

    @equal @model.ns, "gk:test:users"

    done 3

  "test valid user creation": ( done ) ->
    @model.create "bobexample", email: "bob@example.com", ( err, newUser ) =>
      @isNull err
      @ok newUser
      @equal newUser.email, "bob@example.com"

      done 3

  "test valid user creation": ( done ) ->
    @model.create "bobexample", email: "bob@example", ( err, newUser ) =>
      @ok err

      @equal err.message, "email: (pattern) "
      @equal err.constructor.name, "ValidationError"

      done 3

  "test adding a new key which doesn't exist": ( done ) ->
    @model.create "bobexample", email: "bob@example.com", ( err, newUser ) =>
      @isNull err

      @model.addKey "bobexample", "1234", ( err, relationship ) =>
        @ok err
        @equal err.constructor.name, "ValidationError"
        @equal err.message, "Key '1234' doesn't exist."

        done 4

  "test getting a range": ( done ) ->
    # create 51 users
    fixtures = []

    for i in [ 0..50 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          @model.create "user_#{i}", email: "#{i}@example.com", cb

    async.series fixtures, ( err, newUsers ) =>
      @isUndefined err
      @equal newUsers.length, 51

      @model.range 0, 9, ( err, userIds ) =>
        @isNull err
        @equal userIds.length, 10

        @equal userIds[0], "user_0"
        @equal userIds[5], "user_5"
        @equal userIds[9], "user_9"

        @model.range 49, -1, ( err, results ) =>
          @isNull err
          @equal results.length, 2

          @deepEqual results, [ "user_49", "user_50" ]

          done 10

  "test adding a new key which does exist": ( done ) ->
    fixtures = [ ]

    # add a user
    fixtures.push ( cb ) =>
      @model.create "bobexample", email: "bob@example.com", cb

    # add a couple of api keys and associate them with bob
    for val in [ "1234", "5678" ]
      do ( val ) =>
        fixtures.push ( cb ) =>
          @addKeyFixture val, forApi: "twitter", cb

        fixtures.push ( cb ) =>
          @model.addKey "bobexample", val, cb

    fixtures.push ( cb ) =>
      @model.addKey "bobexample", "1234", cb

    async.series fixtures, ( err, results ) =>
      @isUndefined err

      @model.keyCount "bobexample", ( err, count ) =>
        @isNull err
        @equal count, 2

        @model.getKeys "bobexample", ( err, [ firstKey, secondKey ] ) =>
          @isNull err

          @equal firstKey, "1234"
          @equal secondKey, "5678"

          done 6
