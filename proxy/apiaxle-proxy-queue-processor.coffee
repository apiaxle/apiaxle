#!/usr/bin/env coffee

# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.

_ = require "lodash"
urllib = require "url"
async = require "async"

cluster = require "cluster"

{ AxleApp } = require "apiaxle-base"
{ PathGlobs } = require "./lib/path_globs"

class exports.ApiaxleQueueProcessor extends AxleApp
  @plugins = {}

  constructor: ->
    super
    @path_globs = new PathGlobs()

  processHit: ( options, cb ) ->
    { error,
      status_code,
      api_name,
      key_name,
      keyring_names,
      timing,
      parsed_url } = options

    # nothing we can really do here other than log
    return cb error if error and not api_name

    @model( "apifactory" ).find [ api_name ], ( err, results ) =>
      return cb err if err

      all = []

      if error
        if key_name
          all.push ( cb ) =>
            @logger.debug "Logging error #{ error.name } - #{ error.message }"

            model = @model "stats"
            return model.hit api_name, key_name, ( keyring_names or [] ), "error", error.name, cb
      else
        all.push ( cb ) =>
          model = @model "stats"
          return model.hit api_name, key_name, keyring_names, "uncached", status_code, cb

        # the request time in ms
        time = ( timing["end-request"] - timing["start-request"] )

        all.push ( cb ) =>
          timersModel = @model "stattimers"
          multi = timersModel.multi()

          # add more timers here if need be
          timers = [
            ( cb ) -> timersModel.logTiming multi, [ api_name ], "http-request", time, cb
          ]

          async.series timers, ( err ) ->
            return cb err if err
            return multi.exec cb

        all.push ( cb ) =>
          @logCapturedPathsMaybe results[api_name],
                                 key_name,
                                 keyring_names,
                                 parsed_url,
                                 time,
                                 cb

      return async.series all, cb

  logCapturedPathsMaybe: ( api, key_name, keyring_names, parsed_url, timing, cb ) ->
    { pathname, query } = parsed_url

    # only if we have some paths
    return cb null unless api.data.hasCapturePaths

    # this combines timers and counters
    countersModel = @model "capturepaths"

    # fetch the paths we're looking to capture
    api.getCapturePaths ( err, capture_paths ) =>
      return next err if err

      # finally, capture them. Timers and counters.
      matches = @path_globs.matchPathDefinitions pathname, query, capture_paths

      args = [ api.id, key_name, keyring_names ]
      return countersModel.log args..., matches, timing, cb

  error: ( err, type="warn" ) ->
    @logger[type] "#{ err.name } - #{ err.message }"

  run: ->
    queue = @model( "queue" )

    queue.ee.on "hit", ( chan, message ) =>
      @processHit JSON.parse( message ), ->

    try
      queue.listen()
      queue.subscribe "hit"
    catch err
      @error err, "error"
      process.exit 1

if not module.parent
  optimism = require( "optimist" ).options
    f:
      alias: "fork-count"
      default: 1
      describe: "How many internal processes to fork"

  optimism.boolean "help"
  optimism.describe "help", "Show this help screen"

  if optimism.argv.help or optimism.argv._.length > 0
    optimism.showHelp()
    process.exit 0

  if cluster.isMaster
    # fork for each CPU or the specified amount
    cluster.fork() for i in [ 1..optimism.argv["fork-count"] ]

    cluster.on "exit", ( worker, code, signal ) ->
      console.log( "Worker #{ worker.process.pid } died." )
  else
    api = new exports.ApiaxleQueueProcessor
      name: "apiaxle"

    all = []

    all.push ( cb ) -> api.configure cb
    all.push ( cb ) -> api.redisConnect "redisClient", cb
    all.push ( cb ) -> api.redisConnect "redisSubscribeClient", cb
    all.push ( cb ) -> api.loadAndInstansiatePlugins cb
    all.push ( cb ) -> api.run cb

    async.series all, ( err ) ->
      throw err if err
