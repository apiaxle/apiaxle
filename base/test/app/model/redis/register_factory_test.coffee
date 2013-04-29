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

          done 5
