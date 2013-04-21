#!/usr/bin/env coffee

process.env.NODE_ENV = "docs"
_ = require "lodash"
{ exec } = require "child_process"

{ ApiaxleApi } = require "../apiaxle-api"


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
  print "<div class='well' id='#{path}'>"
  print "<h2>#{path}</h2>"

outputDocs = ( path, docs ) ->
  print "<h3><span class='muted'>#{docs.verb}</span> #{docs.title}</h3>"
  outputExample path, docs

  if docs.description
    print "<p>#{docs.description}</p>"

  if docs.input
    print "<h4>Input</h4>"
    outputTable docs.input

  if docs.response
    print "<h4>Response</h4>"
    print docs.response

outputTable = ( obj ) ->
  print "<table class='table'>"
  for param, description of obj
    print "<tr><td>#{param}</td><td>#{description}</td></tr>"
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
      print "<td><a href='##{path}'>#{path}</a></td>"
      print "<td>#{controller.desc()}</td>"
      print "</tr>"
      alreadyOutput[path] = true

  print "</table>"

genExampleData = ( data_description ) ->
  if data_description.indexOf "String"
    return "..."

genExamplePath = ( path ) ->
  example = path.replace ":api", "testapi"
  example = example.replace ":key", "1234"
  return example

genExample = ( path, docs ) ->
  example = "curl"
  example += " -X #{docs.verb}"
  example += " '#{genExamplePath( path ) }'"
  return example

outputExample = ( path, docs ) ->
  print "<p><code>#{genExample( path, docs )}</code></p>"


# curl -v -H "Content-Type: application/json" -X POST -d '{"screencast":{"subject":"tools"}}' \
# http://localhost:3570/index.php/trainingServer/screencast.json

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
        outputDocs controller.path(), controller.docs()
    print "</div>"

    finish()
