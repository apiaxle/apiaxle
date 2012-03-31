async = require "async"

{ ApiaxleTest } = require "../../apiaxle"

class exports.CatchallTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "test only get should be cachable": ( done ) ->
    all = [ ]

    for type in [ "Post", "Put", "Delete" ]
      controller = @application.controller "#{type}Catchall"

      req =
        headers: { }
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

  "test #_cacheControl": ( done ) ->
    controller = @application.controller "GetCatchall"

    tests = [ ]

    tests.push
      req:
        api:
          globalCache: 20
        headers:
          "cache-control": "proxy-revalidate"
      should:
        mustRevalidate: true
        ttl: 20

    tests.push
      req:
        api:
          globalCache: 20
        headers:
          "cache-control": "no-cache"
      should:
        mustRevalidate: false
        ttl: 0

    tests.push
      req:
        api:
          globalCache: 50
        headers: { }
      should:
        mustRevalidate: false
        ttl: 50

    tests.push
      req:
        api:
          globalCache: 0
        headers: { }
      should:
        mustRevalidate: false
        ttl: 0

    tests.push
      req:
        api:
          globalCache: 10
        headers:
          "cache-control": "s-maxage=30"
      should:
        mustRevalidate: false
        ttl: 30

    runnables = [ ]

    for test in tests
      do ( test ) =>
        runnables.push ( cb ) =>
          controller._cacheTtl test.req, ( err, mustRevalidate, ttl ) =>
            @isNull err
            @equal ttl, test.should.ttl
            @equal mustRevalidate, test.should.mustRevalidate

            cb()

    async.series runnables, ( err ) =>
      @ok not err

      done 6

  "test global caching miss": ( done ) ->
    apiOptions =
      apiFormat: "json"
      globalCache: 20

    @newApiAndKey "facebook", apiOptions, "1234", null, ( err ) =>
      @isNull err

      # make sure we don't actually hit facebook
      data = JSON.stringify { two: 2 }

      stub = @stubCatchall 200, data,
        "Content-Type": "application/json"

      requestOptions =
        path: "/cock.bastard?api_key=1234"
        host: "facebook.api.localhost"

      @GET requestOptions, ( err, response ) =>
        @isNull err

        @ok stub.calledOnce

        response.parseJson ( json ) =>
          @isUndefined json.error
          @deepEqual json.two, 2

          # now this call should come from cache
          @GET requestOptions, ( err, response ) =>
            @isNull err

            # we shouldn't have called the http req again
            @ok stub.calledOnce, "result comes from cache"

            @isUndefined json.error
            @deepEqual json.two, 2

            done 9

  "test #_parseCacheControl": ( done ) =>
    controller = @application.controller "GetCatchall"

    res = controller._parseCacheControl
      headers:
        "cache-control": "s-maxage=30, proxy-revalidate"

    @deepEqual res,
      "s-maxage": 30
      "proxy-revalidate": true

    done 1
