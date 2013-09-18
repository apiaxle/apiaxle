# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
url = require "url"
async = require "async"

{ ApiaxleTest } = require "../apiaxle"
{ PathGlobs } = require "../../lib/path_globs"

class exports.PathGlobTests extends ApiaxleTest
  "test #getRegexpForDefinition": ( done ) ->
    @ok ps = new PathGlobs()

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

  "test basic uri parsing": ( done ) ->
    @ok ps = new PathGlobs()

    definitions = [
      "/animal/*"
      "/animal/*/characteristics/*"
    ]

    uris =
      "/": []

      # matches breed absolutely
      "/animal/horse": [ "/animal/*" ]

      # nothing more than :breed matches
      "/animal/horse/characteristics/": [ "/animal/*" ]

      # matches everything
      "/animal/horse/characteristics/tail": definitions

    for uri, matching_defs of uris
      match = ps.matchPathDefinitions uri, {}, definitions
      @deepEqual match, matching_defs

    done 5

  "test #doQueryParamsMatch": ( done ) ->
    @ok ps = new PathGlobs()

    # matches
    @ok ps.doQueryParamsMatch { one: "*" }, { one: "two" }
    @ok ps.doQueryParamsMatch { one: "two" }, { one: "two" }
    @ok ps.doQueryParamsMatch { one: "*" }, { one: 0 }
    @ok ps.doQueryParamsMatch { one: "*" }, { one: false }

    # doesn't match
    @ok not ps.doQueryParamsMatch { one: "two" }, { one: "three" }
    @ok not ps.doQueryParamsMatch { one: "two" }, { one: true }
    @ok not ps.doQueryParamsMatch { one: "two" }, { one: "*" }

    # larger matches
    want =
      one: "two"
      three: "four"
    got = want
    @ok ps.doQueryParamsMatch want, got

    want =
      one: "*"
      three: "four"
    @ok ps.doQueryParamsMatch want, got

    want =
      one: "*"
      three: "*"
    @ok ps.doQueryParamsMatch want, got

    # larger non-matches
    want =
      one: "*"
      three: "four"
    got =
      one: "two"
      three: "five"
    @ok not ps.doQueryParamsMatch want, got

    done 12

  "test uri parsing including query params": ( done ) ->
    @ok ps = new PathGlobs()

    definitions = [
      "/animal/*?sort=asc&meta=*"
    ]

    uris =
      "/": []
      "/animal/dog?sort=asc": []
      "/animal/dog?sort=asc": []
      "/animal/dog?sort=asc&meta=hello": definitions

    for uri, matching_defs of uris
      { pathname, query } = url.parse( uri, true )

      match = ps.matchPathDefinitions pathname, query, definitions
      @deepEqual match, matching_defs

    done 5
