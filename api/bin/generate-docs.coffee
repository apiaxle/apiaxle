#!/usr/bin/env coffee

_ = require "underscore"
{ exec } = require "child_process"

{ ApiaxleApi } = require "../apiaxle-api"

print = console.log

alreadyPrinted = {}
printOnce = ( toPrint ) ->
  return if alreadyPrinted[ toPrint ]?

  alreadyPrinted[ toPrint ] = 1
  print toPrint

gk = new ApiaxleApi()

exec "git rev-parse --abbrev-ref HEAD", ( err, stdout ) ->
  branch = stdout.replace /\n/g, ""

  outputHeaders = ( ) ->
    """---
    layout: apidocs
    title: "Api documentation (generated from '#{ branch }'"
    ---
    """
  gk.script ( finish ) ->
    # we need to know the controllers
    gk.configureControllers()

    print outputHeaders()

    # sort by the controller path
    sorted = _.sortBy gk.controllers, ( x ) -> x.path()

    print "This documentation was generated from branch '#{ branch }'"

    for controller in sorted
      # h1, the path of the controller
      printOnce "# #{controller.path()}"

      print "## #{controller.desc()} (#{controller.constructor.verb.toUpperCase()})"
      print "#{controller.docs()}\n"

    finish()
