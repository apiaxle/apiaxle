# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
request = require "request"
async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"

class exports.RegisterTest extends FakeAppTest
  @empty_db_on_setup = true

  "test register": ( done ) ->
    model = @app.model( "register" )

    # not registered yet
    model.isRegistered ( err, registered ) =>
      @ok not err
      @ok registered is false

      stub = @getStub request, "get", ( options, cb ) =>
        @match options.url, /email=phil%40apiaxle.com/
        @match options.url, /name=Phil%20Jackson/

        cb()

      # register them
      model.register "phil@apiaxle.com", "Phil Jackson", ( err ) =>
        @ok not err
        @ok stub.calledOnce

        # now is registered
        model.isRegistered ( err, registered ) =>
          @ok not err
          @ok registered is true

          done 8

  "test register with invalid email": ( done ) ->
    model = @app.model( "register" )

    model.register "asdfg@blah", "affds", ( err ) =>
      @ok err
      @equal err.message, "Invalid email address."
      @equal err.name, "ValidationError"

      model.register "asdfgblah.com", "affds", ( err ) =>
        @ok err
        @equal err.message, "Invalid email address."

        done 5
