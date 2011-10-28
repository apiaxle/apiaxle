#!/usr/bin/env coffee

sys = require "sys"

{ Gatekeeper } = require "../gatekeeper"

results =
  success: 0
  failed: 0
  persecond: { }

limits =
  qps: ( process.argv[2] or 1 )
  qpd: ( process.argv[3] or 2000 )

process.on "SIGINT", ( ) ->
  console.log( results )
  process.exit 1

gk = new Gatekeeper()
gk.script ( finish ) ->
  model = gk.model( "apiLimits" )
  model.flush()

  f = ( ) ->
    now = new Date()
    timeStr = "#{ now.getMinutes() }-#{ now.getSeconds() }"
    results.persecond[ timeStr ] or= 0

    model.ttl [ "qps", "bob", "1234" ], ( err, ttl ) ->
      model.withinLimits "bob", "1234", limits, ( err, [ currentQps, currentQpd ] ) ->
        if err
          results.failed += 1

          return setTimeout f, 200

        model.apiHit "bob", "1234", ( err, [ newQps, newQpd ] ) ->
          throw err if err

          sys.print "#{ ttl }.#{ newQps }.#{ newQpd } "

          results.success += 1
          results.persecond[ timeStr ] += 1

          return setTimeout f, 200

  f()
