{ TwerpTest } = require "twerp"
parser = require "../../repl/lib/parser"

class exports.TestParser extends TwerpTest
  "test the parser": ( done ) ->
    shoulds =
      'This is a "test parse"': [ "This", "is", "a", "test parse" ]
      "This is a 'test parse'": [ "This", "is", "a", "test parse" ]
      '1 2 3 4': [ 1, 2, 3, 4 ]
      'api create facebook "endPoint"="graph"': [ "api", "create", "facebook", { endPoint: "graph" } ]
      '"str" key=value 123': [ "str", { key: "value" }, 123 ]

    for from, to of shoulds
      @deepEqual parser( from ), to

    done 4
