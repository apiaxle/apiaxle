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
        controller._cacheTtl req, ( err, ttl ) =>
          @isNull err
          @equal ttl, 0

          cb()

    async.series all, ( err, res ) =>
      done 6

  "test #_cacheTtl simple, global cache": ( done ) ->
    controller = @application.controller "GetCatchall"

    req =
      headers: { }
      api:
        globalCache: 20

    controller._cacheTtl req, ( err, ttl ) =>
      @isNull err
      @equal ttl, 20

      done 2

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
