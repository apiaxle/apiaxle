#!/usr/bin/env coffee

{ Gatekeeper } = require "../gatekeeper"

gk = new Gatekeeper()
gk.script ( finish ) ->
  results =
    success: 0
    failed: 0

  limits =
    qps: 2
    qpd: 10

  model = gk.model( "apiLimits" )
  model.flush()

  f = ( ) ->
    model.withinLimits "bob", "1234", limits, ( err, [ currentQps, currentQpd ] ) ->
      if err
        results.failed += 1
        setTimeout f, 500
        return

      model.apiHit "bob", "1234", ( err, [ newQps, newQpd ] ) ->
        throw err if err

        results.success += 1
        console.log( "#{newQps} - #{newQpd}" )

        setTimeout f, 100

   f 800