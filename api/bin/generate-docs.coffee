#!/usr/bin/env coffee

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

api = new ApiaxleApi
  env: "docs"
  name: "apiaxle"

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
  outputExample controller

  if docs.description
    print "<p>#{ docs.description }</p>"

  if docs.input
    print "<h4>Input</h4>"
    outputParams docs.input

  if params = controller.queryParams?().properties
    print "<h4>Params</h4>"
    outputParams params

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
      print "<td>#{ controller.docs().title }</td>"
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

genExample = ( controller ) ->
  example = "curl -X #{ controller.constructor.verb } '#{ genExamplePath( controller.path() ) }'"

  docs = controller.docs()
  if docs.input
    example += " -d '#{ genExampleInput( docs.input ) }'"

  return example

outputExample = ( controller ) ->
  print "<p><code>#{ genExample controller }</code></p>"

exec "git rev-parse --abbrev-ref HEAD", ( err, stdout ) ->
  console.error( err ) if err

  branch = stdout.replace /\n/g, ""

  api.script ( err, finish ) ->
    throw err if err

    # sort by the controller path
    sorted = _.sortBy api.plugins.controllers, ( x ) -> x.path()

    print "This documentation was generated from branch '#{ branch }'"

    outputQuickReference sorted

    for controller in sorted
      # h1, the path of the controller
      printPath controller.path()

      if controller.docs
        outputDocs controller

    print "</div>"

    finish()
