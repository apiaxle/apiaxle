async = require "async"

{ ValidationError } = require "../../lib/error"
{ FakeAppTest } = require "../apiaxle_base"

{ ReplHelper } = require "../../repl/lib/repl"

class exports.KeyCommandTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup repl helper": ( done ) ->
    @repl = new ReplHelper @app

    done()

  "setup an api": ( done ) ->
    fixture =
      api:
        facebook: {}
        twitter: {}

    @fixtures.create fixture, ( err, [ facebookApi, twitterApi ] ) =>
      @facebookApi = facebookApi
      @twitterApi = twitterApi

      done()

  "test creating a key": ( done ) ->
    command = [ "key", "create", "phil", { forApis: 'twitter, facebook' } ]

    @repl.runCommands command, ( err, info ) =>
      @isUndefined err?.message
      @ok info

      @twitterApi.supportsKey "phil", ( err, does_support ) =>
        @isNull err
        @ok does_support

        @facebookApi.supportsKey "phil", ( err, does_support ) =>
          @isNull err
          @ok does_support

          @app.model( "keyFactory" ).find "phil", ( err, dbKey ) =>
            @isNull err
            @ok dbKey

            dbKey.supportedApis ( err, apis ) =>
              @isNull err
              @deepEqual apis, [ "twitter", "facebook" ]

              done 10
