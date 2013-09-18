#!/usr/bin/env coffee

# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.

express = require "express"

app = express.createServer()
app.configure ( ) ->
  express.bodyParser.parse =
    "application/x-www-form-urlencoded": ( x ) -> x,
    "application/json": ( x ) -> x

  app.use express.bodyParser()

app.all "*", ( req, res, next ) ->
  { milliseconds, data } = req.query

  milliseconds or= Math.floor( Math.random() * 1000 )
  data or= JSON.stringify
    time: milliseconds
    query: req.query
    body: req.body
    path: req.url

  done = () ->
    try
      res.json JSON.parse( data )
    catch err
      res.json err

  if milliseconds
    console.log( data )
    setTimeout done, milliseconds
  else
    done()

port = ( process.argv[2] or 2000 )
app.listen port
