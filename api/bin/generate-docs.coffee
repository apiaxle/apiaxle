#!/usr/bin/env coffee

_ = require "underscore"

{ ApiaxleApi } = require "../apiaxle_api"

print = console.log

alreadyPrinted = {}
printOnce = ( toPrint ) ->
  return if alreadyPrinted[ toPrint ]?

  alreadyPrinted[ toPrint ] = 1
  print toPrint

gk = new ApiaxleApi()
gk.logger =
  debug: ( ) ->
  info: ( ) ->

outputHeaders = ( ) ->
  """---
  layout: apidocs
  title: "Api documentation"
  ---
  """
gk.script ( finish ) ->
  # we need to know the controllers
  gk.configureControllers()

  print outputHeaders()

  # sort by the controller path
  sorted = _.sortBy gk.controllers, ( x ) -> x.path()

  for controller in sorted
    # h1, the path of the controller
    printOnce "# #{controller.path()}"

    print "## #{controller.desc()} (#{controller.constructor.verb.toUpperCase()})"
    print "#{controller.docs()}\n"

  finish()
