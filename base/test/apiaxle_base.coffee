# always run as test
process.env.NODE_ENV = "test"

async = require "async"

{ Application } = require "../lib/application"
{ AppTest } = require "../lib/test"

class TestApp extends Application

class exports.FakeAppTest extends AppTest
  @appClass = TestApp

  addKeyFixture: ( key, options, cb ) ->
    forApi = ( options.forApi or= "twitter" )

    apiModel = @application.model( "api" )
    apiModel.find options.forApi, ( err, dbApi ) =>
      return cb err if err

      fixtures = []

      fixtures.push ( cb ) =>
        if not dbApi?
          return apiModel.create forApi, endPoint: "#{forApi}.api.localhost", cb

        return cb null, dbApi

      # add the new key
      fixtures.push ( cb ) =>
        keyModel = @application.model "key"
        keyModel.create key, options, cb

      async.series fixtures, cb
