#!/usr/bin/env coffee

_ = require "lodash"
async = require "async"
sinon = require "sinon"

{ Stats } = require "../../base/app/model/redis/stats"
{ ApiaxleProxy } = require "../apiaxle-proxy"

rand = ( arr ) ->
  index = Math.floor( ( Math.random() * arr.length ) )
  return arr[index]

api = new ApiaxleProxy()
api.script ( finish ) ->
  listers = []

  listers.push ( cb ) -> api.model( "apiFactory" ).range 0, 1000, cb
  listers.push ( cb ) -> api.model( "keyFactory" ).range 0, 1000, cb

  async.series listers, ( err, [ apis, keys ] ) ->
    stats = api.model "stats"

    from = ( Date.now() - 20000 )
    real = Date.now()

    clock = sinon.useFakeTimers from

    possible_types = [ "cached", "uncached", "error" ]
    possible_status = [ 200, 400, 404 ]

    key_pack = []

    for i in [ from..real ] by 1000
      redis_key = [ rand( apis ),
                    rand( keys ),
                    rand( possible_types ),
                    rand( possible_status ) ]

      do ( redis_key ) ->
        key_pack.push ( cb ) ->
          stats.hit redis_key..., ( err ) ->
            clock.tick 1000
            return cb err, redis_key

    async.series key_pack, finish
