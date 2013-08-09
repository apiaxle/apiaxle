# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
url = require "url"
async = require "async"

{ ApiaxleTest } = require "../apiaxle"
{ PathSplitter } = require "../../lib/path_splitter"

class exports.PathSplitterTest extends ApiaxleTest
  "test basic splitting": ( done ) ->
    @ok ps = new PathSplitter()

    urls =
      "/": [ "/" ]
      "/one": [ "one/" ]
      "/one/two/three": [ "one/", "one/two/", "one/two/three/" ]

    for uri, details of urls
      parsed = ps.parse( url.parse( uri, true ) )
      @deepEqual parsed, details

    done 4
