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

      # register them
      model.register ( err ) =>
        @ok not err

        # now is registered
        model.isRegistered ( err, registered ) =>
          @ok not err
          @ok registered is true

          done 5
