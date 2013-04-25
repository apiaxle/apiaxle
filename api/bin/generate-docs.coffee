#!/usr/bin/env coffee

process.env.NODE_ENV = "docs"
_ = require "lodash"
{ exec } = require "child_process"

{ ApiaxleApi } = require "../apiaxle-api"

example_map =
  endPoint: "testapi.api.local"

print = console.log

alreadyPrinted = {}

printOnce = ( toPrint ) ->
  return if alreadyPrinted[ toPrint ]?

  alreadyPrinted[ toPrint ] = 1
  print toPrint

gk = new ApiaxleApi()

# Prints the path if it hasn't already, also opens and closes the container
printPath = ( path ) ->
  if alreadyPrinted[path]
    print "<hr />"
    return

  if _.size( alreadyPrinted ) > 0
    # Close the previous section
    print "</div>"

  alreadyPrinted[ path ] = true
  print "<div class='well' id='#{ path }'>"
  print "<h2>#{ path }</h2>"

outputDocs = ( controller ) ->
  docs = controller.docs()

  print "<h3><span class='muted'>#{ controller.constructor.verb }</span> #{ docs.title }</h3>"
  outputExample controller.path(), docs

  if docs.description
    print "<p>#{ docs.description }</p>"

  if docs.input
    print "<h4>Input</h4>"
    outputParams docs.input

  if docs.params
    print "<h4>Params</h4>"
    outputParams docs.params

  if docs.response
    print "<h4>Response</h4>"
    print docs.response

outputTable = ( obj ) ->
  print "<table class='table'>"
  for param, description of obj
    print "<tr><td>#{ param }</td><td>#{ description }</td></tr>"
  print "</table>"

outputQuickReference = ( controllers ) ->
  alreadyOutput = {}
  print "<h2>Quick Reference</h2>"
  print "<table class='table'>"
  print "<tr><th>Endpoint</th><th>Description</th></tr>"

  for controller in controllers
    if not alreadyOutput[controller.path()]
      path = controller.path()
      print "<tr>"
      print "<td><a href='##{ path }'>#{ path }</a></td>"
      print "<td>#{ controller.desc() }</td>"
      print "</tr>"
      alreadyOutput[path] = true

  print "</table>"

outputParams = ( params ) ->
  data = {}
  for param, props of params
    docs = props.docs || ""
    if props.optional
      docs = "(optional) #{ docs }"

    if props.default?
      docs = "(default: #{ props.default }) #{ docs }"

    data[param] = docs

  outputTable data

genExampleData = ( field, data_description ) ->
  if example_map[field]
    return example_map[field]

  if data_description.indexOf "String" >= 0
    return "..."

genExamplePath = ( path ) ->
  example = path.replace ":api", "testapi"
  example = example.replace ":key", "1234"
  return "http://localhost#{ example }"

genExampleInput = ( input ) ->
  output = {}
  for field, props of input
    if props.docs and (not props.optional? and not props.default?)
      output[field] = genExampleData field, props.docs

  return JSON.stringify output

genExample = ( path, docs ) ->
  example = "curl -X #{ docs.verb } '#{ genExamplePath( path ) }'"

  if docs.input
    example += " -d '#{ genExampleInput( docs.input ) }'"

  return example

outputExample = ( path, docs ) ->
  print "<p><code>#{ genExample path, docs }</code></p>"

exec "git rev-parse --abbrev-ref HEAD", ( err, stdout ) ->
  branch = stdout.replace /\n/g, ""

  gk.script ( finish ) ->
    # we need to know the controllers
    gk.configureControllers()

    # sort by the controller path
    sorted = _.sortBy gk.controllers, ( x ) -> x.path()

    print "This documentation was generated from branch '#{ branch }'"

    outputQuickReference sorted

    for controller in sorted
      # h1, the path of the controller
      printPath controller.path()

      if controller.docs
        outputDocs controller
    print "</div>"

    finish()
