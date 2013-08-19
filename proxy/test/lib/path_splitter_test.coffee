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
      "/animal/sound/*/file/*":
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

  "test basic path parsing": ( done ) ->
    @ok ps = new PathSplitter()

    definitions = [
      "/animal/*"
      "/animal/*/characteristics/*"
    ]

    paths =
      "/": []

      # matches breed absolutely
      "/animal/horse": [ "/animal/*" ]

      # nothing more than :breed matches
      "/animal/horse/characteristics/": [ "/animal/*" ]

      # matches everything
      "/animal/horse/characteristics/tail": definitions

    for path, matching_defs of paths
      match = ps.matchPathDefinitions path, definitions
      @deepEqual match, matching_defs

    done 5
