# always run as test
process.env.NODE_ENV = "test"

async = require "async"

{ AxleApi } = require "../lib/application"
{ AppTest } = require "../lib/test"

class TestApp extends AxleApi

class exports.FakeAppTest extends AppTest
  @appClass = TestApp
