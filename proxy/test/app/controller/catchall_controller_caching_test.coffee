async = require "async"

{ ApiaxleTest } = require "../../apiaxle"

class exports.CatchallTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "test only get should be cachable": ( done ) ->
    all = []

    for type in [ "Post", "Put", "Delete" ]
      controller = @app.controller "#{type}Catchall"

      req =
        headers: {}
        api:
          globalCache: 20

      all.push ( cb ) =>
        controller._cacheTtl req, ( err, mustRevalidate, ttl ) =>
          @ok not mustRevalidate
          @isNull err
          @equal ttl, 0

          cb()

    async.series all, ( err, res ) =>
      done 9

  _runCacheControlTests: ( tests, cb ) ->
    controller = @app.controller "GetCatchall"

    runnables = []

    for test in tests
      do ( test ) =>
        runnables.push ( cb ) =>
          controller._cacheTtl test.req, ( err, mustRevalidate, ttl ) =>
            @isNull err
            @equal ttl, test.should.ttl
            @equal mustRevalidate, test.should.mustRevalidate

            cb()

    async.series runnables, cb

  "test #_cacheControl 'no-cache'": ( done ) ->
    tests = []

    tests.push
      req:
        api:
          globalCache: 10
        headers:
          "cache-control": "no-cache"
      should:
        mustRevalidate: false
        ttl: 0

    tests.push
      req:
        api:
          globalCache: 10
        headers:
          "cache-control": "s-maxage=30, no-cache"
      should:
        mustRevalidate: false
        ttl: 0

    tests.push
      req:
        api:
          globalCache: 10
        headers:
          "cache-control": "s-maxage=30, proxy-revalidate"
      should:
        mustRevalidate: true
        ttl: 30

    @_runCacheControlTests tests, ( err ) =>
      @ok not err

      done 10

  "test #_cacheControl 's-maxage'": ( done ) ->
    tests = []

    # check that s-maxage overrides globalCache
    tests.push
      req:
        api:
          globalCache: 10
        headers:
          "cache-control": "s-maxage=30"
      should:
        mustRevalidate: false
        ttl: 30

    # no-cache overrides s-maxage, which overrides globalCache
    tests.push
      req:
        api:
          globalCache: 60
        headers:
          "cache-control": "s-maxage=30, no-cache"
      should:
        mustRevalidate: false
        ttl: 0

    @_runCacheControlTests tests, ( err ) =>
      @ok not err

      done 7

  "test global caching miss": ( done ) ->
    fix =
      api:
        facebook:
          apiFormat: "json"
          globalCache: 20
      key:
        1234:
          forApi: "facebook"

    @fixtures.create fix, ( err ) =>
      @isNull err

      # make sure we don't actually hit facebook
      data = JSON.stringify { two: 2 }

      stub = @stubCatchall 200, data,
        "Content-Type": "application/json"

      requestOptions =
        path: "/cock.bastard?api_key=1234"
        host: "facebook.api.localhost"

      @stubDns { "facebook.api.localhost": "127.0.0.1" }
      @GET requestOptions, ( err, response ) =>
        @isNull err

        @ok stub.calledOnce

        response.parseJson ( err, json ) =>
          @isNull err
          @isUndefined json.error
          @deepEqual json.two, 2

          # now this call should come from cache
          @GET requestOptions, ( err, response ) =>
            @isNull err

            # we shouldn't have called the http req again
            @ok stub.calledOnce, "result comes from cache"

            @isUndefined json.error
            @deepEqual json.two, 2

            done 10

  "test #_parseCacheControl": ( done ) ->
    controller = @app.controller "GetCatchall"

    res = controller._parseCacheControl
      headers:
        "cache-control": "s-maxage=30, proxy-revalidate"

    @deepEqual res,
      "s-maxage": 30
      "proxy-revalidate": true

    done 1

  "test caching at controller level": ( done ) ->
    fixture =
      api:
        facebook:
          apiFormat: "json"
      key:
        1234:
          forApi: "facebook"

    @fixtures.create fixture, ( err ) =>
      @isNull err

      # make sure we don't actually hit facebook
      data = JSON.stringify { two: 2 }

      stub = @stubCatchall 202, data,
        "Content-Type": "application/json"

      requestOptions =
        path: "/cock.bastard?api_key=1234"
        host: "facebook.api.localhost"
        headers:
          "Cache-Control": "s-maxage=30"

      @stubDns { "facebook.api.localhost": "127.0.0.1" }
      @GET requestOptions, ( err, response ) =>
        @isNull err
        @ok stub.calledOnce

        @equal response.statusCode, 202
        @equal response.headers[ "content-type" ], "application/json"

        response.parseJson ( err, json ) =>
          @isNull err
          @isUndefined json.error
          @deepEqual json.two, 2

          # now this call should come from cache
          @GET requestOptions, ( err, response ) =>
            @isNull err

            @equal response.statusCode, 202
            @equal response.headers[ "content-type" ], "application/json"

            response.parseJson ( err, json ) =>
              @isNull err
              @isUndefined json.error

              # we shouldn't have called the http req again
              @ok stub.calledOnce, "result comes from cache"

              @isUndefined json.error
              @deepEqual json.two, 2

              done 16

  "test caching at controller level (no-cache)": ( done ) ->
    fixture =
      api:
        facebook:
          apiFormat: "json"
          globalCache: 30
      key:
        1234:
          forApi: "facebook"        

    @fixtures.create fixture, ( err ) =>
      @isNull err

      # make sure we don't actually hit facebook
      data = JSON.stringify { two: 2 }

      stub = @stubCatchall 200, data,
        "Content-Type": "application/json"

      requestOptions =
        path: "/cock.bastard?api_key=1234"
        host: "facebook.api.localhost"
        headers:
          "Cache-Control": "no-cache"

      @stubDns { "facebook.api.localhost": "127.0.0.1" }
      @GET requestOptions, ( err, response ) =>
        @isNull err

        @ok stub.calledOnce

        response.parseJson ( err, json ) =>
          @isNull err
          @isUndefined json.error
          @deepEqual json.two, 2

          # now this call should come from cache
          @GET requestOptions, ( err, response ) =>
            @isNull err

            # we shouldn't have called the http req again
            @ok stub.calledTwice, "result comes from http request"

            @isUndefined json.error
            @deepEqual json.two, 2

            done 10

  "test caching at controller level (revalidate)": ( done ) ->
    fixture =
      api:
        facebook:
          apiFormat: "json"
          globalCache: 30
      key:
        1234:
          forApi: "facebook"

    @fixtures.create fixture, ( err ) =>
      @isNull err

      # make sure we don't actually hit facebook
      data = JSON.stringify { two: 2 }

      stub = @stubCatchall 200, data,
        "Content-Type": "application/json"

      requestOptions =
        path: "/cock.bastard?api_key=1234"
        host: "facebook.api.localhost"
        headers:
          "Cache-Control": "s-maxage=30, proxy-revalidate"

      @stubDns { "facebook.api.localhost": "127.0.0.1" }
      @GET requestOptions, ( err, response ) =>
        @isNull err

        @ok stub.calledOnce

        response.parseJson ( err, json ) =>
          @isNull err
          @isUndefined json.error
          @deepEqual json.two, 2

          # now this call should come from cache
          @GET requestOptions, ( err, response ) =>
            @isNull err

            # we shouldn't have called the http req again
            @ok stub.calledTwice, "result comes from http request"

            @isUndefined json.error
            @deepEqual json.two, 2

            done 10
