#!/usr/bin/env coffee

express = require "express"

app = express.createServer()
app.configure ( ) ->
  express.bodyParser.parse =
    "application/x-www-form-urlencoded": ( x ) -> x,
    "application/json": ( x ) -> x

  app.use express.bodyParser()

app.all "*", ( req, res, next ) ->
  { seconds, data } = req.query

  seconds or= Math.floor( Math.random() * 11 )
  data or= JSON.stringify
    time: seconds
    query: req.query
    body: req.body

  done = () ->
    try
      res.json JSON.parse( data )
    catch err
      res.json err

  if seconds and milli = ( seconds * 1000 )
    console.log( data )
    setTimeout done, milli
  else
    done()

port = ( process.argv[2] or 2000 )
app.listen port
