# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
url = require "url"
async = require "async"

{ ApiaxleTest } = require "../apiaxle"
{ PathSplitter } = require "../../lib/path_splitter"

class exports.PathSplitterTest extends ApiaxleTest
  "test #getRegexpForDefinition": ( done ) ->
    @ok ps = new PathSplitter()

    # definition and stuff that should/shouldn't match
    definition_tests =
      "/animal/sound/:noise/file/:finder":
        should_match: [
          "/animal/sound/bark/file/blah",
          "/animal/sound/bark/file/blah/",
          "/animal/sound/bark/file/hello world",
          "/animal/sound/yap/file/hello?one=two" ]
        shouldnt_match: [
          "/animal/",
          "/animal/sound/bark/",
          "/animal/sound/bark/file",
        ]

    for definition, tests of definition_tests
      @ok re = ps.getRegexpForDefinition definition
      @ok re instanceof RegExp

      @match test, re for test in tests.should_match
      @noMatch test, re for test in tests.shouldnt_match

    done 10

  # "test basic splitting": ( done ) ->
  #   @ok ps = new PathSplitter()

  #   urls =
  #     "/": [ "/" ]
  #     "/one": [ "one/" ]
  #     "/one/two/three": [ "one/", "one/two/", "one/two/three/" ]

  #   for uri, details of urls
  #     parsed = ps.parse( url.parse( uri, true ) )
  #     @deepEqual parsed, details

  #   done 4
