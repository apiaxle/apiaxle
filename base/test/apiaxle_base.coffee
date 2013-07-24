# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
# always run as test
process.env.NODE_ENV = "test"

async = require "async"

{ AxleApp } = require "../lib/application"
{ AppTest } = require "../lib/test"

class TestApp extends AxleApp
  @plugins = {}

class exports.FakeAppTest extends AppTest
  @appClass = TestApp
