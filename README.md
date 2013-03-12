# Api Axle

http://apiaxle.com

A free, locally hosted API management solution. A proxy for your api,
statistics for your api & a powerful api of its own.

There are three components which make up the Api Axle system:

## The proxy

    $ npm install apiaxle-proxy

This is the aspect of the system which does the actual proxying. It
sits in front of your API and does the authentication, key checking,
queries per day/second checking. This is the bit you want if you want
anything. More detail on the [main site](http://apiaxle.com).

## The API

    $ npm install apiaxle-api

This is the (optional) API for managing users, keys and
endpoints. Once installed, run it with:

    $ apiaxle-api

## The REPL

    $ npm install apiaxle-repl

A way to administer your ApiAxle installation via a command line. Once
installed, run it with:

    $ apiaxle

You then get a prompt where you can type `help` to find out more.

## The base libs

This is a set of libraries which is required for the above components.

# Installation

Check the [main site](http://apiaxle.com) for more detailed
installation instructions.

# Build

* master: [![Build Status](https://secure.travis-ci.org/apiaxle/apiaxle.png?branch=master)](http://travis-ci.org/apiaxle/apiaxle)
* develop: [![Build Status](https://secure.travis-ci.org/apiaxle/apiaxle.png?branch=develop)](http://travis-ci.org/apiaxle/apiaxle)
