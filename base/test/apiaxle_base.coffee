# always run as test
process.env.NODE_ENV = "test"

async = require "async"

{ Application } = require "../lib/application"
{ AppTest } = require "../lib/test"

class TestApp extends Application

class exports.FakeAppTest extends AppTest
  @appClass = TestApp
