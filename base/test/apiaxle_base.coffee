# always run as test
process.env.NODE_ENV = "test"

async = require "async"

{ AxleApp } = require "../lib/application"
{ AppTest } = require "../lib/test"

class TestApp extends AxleApp
  @plugins = {}

class exports.FakeAppTest extends AppTest
  @appClass = TestApp
