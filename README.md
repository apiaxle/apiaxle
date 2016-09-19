# Api Axle

[![Gitter](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/apiaxle/apiaxle?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

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

# Docker

## Docker image
This repository is auto-built and published as
[mapzen/apiaxle](https://hub.docker.com/r/mapzen/apiaxle/).

## Dockerfiles
This project uses two `Dockerfile`s, one for production usage named `Dockerfile`,
and a second for development of ApiAxle itself, named `Dockerfile-development`.
Docker Compose is configured to build the development version for you, see
below for examples.

## Environment Variables
Environment variables can be used to configure `NODE_ENV`, `REDIS_HOST`,
`REDIS_PORT`, and `DEBUG_MODE`. Below are defaults for production:

 - `NODE_ENV` = `production`
 - `REDIS_HOST` = `redis`
 - `REDIS_PORT` = `6379`
 - `DEBUG_MODE` = `false`

## Start services
```
docker-compose up -d redis
docker-compose up -d api
docker-compose up -d proxy
```

## Run repl
```
docker-compose run repl
```

## Run tests
```
docker-compose run repl test
```

## Enter container
```
docker-compose run --entrypoint sh repl
```

### Example adding an api and key:
```
api acme create endPoint='localhost:8000'
key 1234 create
api acme linkkey 1234
```

### Example curl:
```
curl localhost:3000?api_key=1234 -H 'Host: acme.api.localhost'
```
