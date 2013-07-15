{ TwerpTest } = require "twerp"

# always run as test
process.env.NODE_ENV = "test"

tconst = require "../lib/time_constants"

class exports.TimeConstants extends TwerpTest
  "test all times": ( done ) ->
    @equal tconst.seconds( 1 ), 1
    @equal tconst.seconds( 20 ), 20

    @equal tconst.minutes( 1 ), 60
    @equal tconst.minutes( 20 ), 1200

    @equal tconst.hours( 1 ), 3600
    @equal tconst.hours( 20 ), 72000

    @equal tconst.weeks( 1 ), 604800
    @equal tconst.weeks( 20 ), 12096000

    done 6
