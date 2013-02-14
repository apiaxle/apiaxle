#!/usr/bin/env coffee
# -*- mode: coffee; -*-

util = require "util"
async = require "async"

{ ReplHelper } = require "./lib/repl"
{ Application } = require "apiaxle.base"

# create a new application for scripting
class AxleRepl extends Application

axle = new AxleRepl()
axle.script ( cb ) ->
  replHelper = new ReplHelper axle
  replHelper.initReadline cb

  replHelper.topLevelInput()
