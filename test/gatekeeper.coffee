# always run as test
process.env.NODE_ENV = "test"

fs            = require "fs"
http          = require "http"
path          = require "path"
sinon         = require "sinon"
async         = require "async"

{ Gatekeeper } = require "../gatekeeper"
{ TwerpTest }  = require "twerp"

gatekeeper_mem = null
class exports.GatekeeperTest extends TwerpTest
  @port = 26100

  constructor: ( options ) ->
    # avoid re-reading configuration and stuff
    @gatekeeper = if gatekeeper_mem
      gatekeeper_mem
    else
      gatekeeper_mem = new Gatekeeper().configureModels()

    @stubs = [ ]
    @spies  = [ ]

    super options

  startWebserver: ( done ) ->
    @gatekeeper.run "127.0.0.1", @constructor.port, done

  start: ( done ) ->
    chain = [ ]

    if @constructor.start_webserver
      chain.push ( cb ) =>
        @startWebserver cb

    # chain this as it's possible the parent class will implement
    # functionality in `start`
    async.parallel chain, done

  finish: ( done ) ->
    # this is synchronous
    @gatekeeper.app.close( ) if @constructor.start_webserver
    @gatekeeper.redisClient.quit( )

    super done

  "teardown restore stubs": ( done ) ->
    # restore any stubbed functions
    stub.restore( ) for stub in @stubs
    spy.restore( ) for spy in @stubs

    done( )
