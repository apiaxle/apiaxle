# Api Axle

http://apiaxle.com

A free, locally hosted API management solution. A proxy for your api,
statistics for your api & a powerful api of its own.

There are three components which make up the Api Axle system:

## The proxy (apiaxle.git)

https://github.com/philjackson/apiaxle

This is the aspect of the system which does the actual proxying.

## The API (apiaxle.api.git)

https://github.com/philjackson/apiaxle.api

This is the (optional) API for managing users, keys and endpoints.

## The base libs (apiaxle.base.git)

https://github.com/philjackson/apiaxle.base

This is a set of libraries which is required for both of the above
components.

# Installation

    $ mkdir components && cd components
    $ curl https://raw.github.com/philjackson/apiaxle/master/bin/setup-apiaxle.bash | bash
