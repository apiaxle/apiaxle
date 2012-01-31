async = require "async"

{ ApiaxleTest } = require "../../../apiaxle"

class exports.KeyControllerTest extends ApiaxleTest
  @start_webserver = true
  @empty_db_on_setup = true

  "setup Api": ( done ) ->
    details =
      endPoint: "api.twitter.com"

    @apiKeyModel = @application.model( "apiKey" )

    @application.model( "api" ).create "twitter", details, ( err, @newApi ) ->
      done()

  "test GET a valid key": ( done ) ->
    @apiKeyModel.create "1234", forApi: "twitter", ( err, newKey ) =>
      @isNull err
      @ok newKey

      # now try and get it
      @GET path: "/v1/key/1234", ( err, res ) =>
        res.parseJson ( json ) =>
          @isNumber parseInt( json.qps )
          @isNumber parseInt( json.qpd )

          done 4

  "test GET a non-existant key": ( done ) ->
    # now try and get it
    @GET path: "/v1/key/1234", ( err, res ) =>
      @isNull err
      @equal res.statusCode, 404

      res.parseJson ( json ) =>
        @ok json.error
        @equal json.error.type, "NotFoundError"

        done 4

  "test GET a non-existant key": ( done ) ->
    # now try and get it
    @GET path: "/v1/key/1234", ( err, res ) =>
      @isNull err
      @equal res.statusCode, 404

      res.parseJson ( json ) =>
        @ok json.error
        @equal json.error.type, "NotFoundError"

        done 4

  "test POST a valid key": ( done ) ->
    options =
      path: "/v1/key/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        forApi: "twitter"
        qps: 1
        qpd: 100

    @POST options, ( err, res ) =>
      res.parseJson ( json ) =>
        @equal json.qps, "1"
        @equal json.qpd, "100"
        @equal json.forApi, "twitter"

        # check it went in
        @apiKeyModel.find "1234", ( err, dbKey ) =>
          @isNull err

          @equal dbKey.qps, "1"
          @equal dbKey.qpd, "100"
          @equal dbKey.forApi, "twitter"
          @ok dbKey.createdAt

          done 8

  "test POST with an invalid key": ( done ) ->
    options =
      path: "/v1/key/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        forApi: "twitter"
        qps: "invalid"
        qpd: 100

    @POST options, ( err, res ) =>
      res.parseJson ( json ) =>
        @ok json.error
        @equal json.error.type, "ValidationError"
        @equal json.error.message, "qps: (type) Invalid type"

        done 3

  "test PUT with an existing key": ( done ) ->
    options =
      path: "/v1/key/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        forApi: "twitter"
        qps: 30
        qpd: 1000

    @apiKeyModel.create "1234", forApi: "twitter", ( err, origKey ) =>
      @isNull err
      @ok origKey

      @PUT options, ( err, res ) =>
        @equal res.statusCode, 200

        @apiKeyModel.find "1234", ( err, dbKey ) =>
          @equal dbKey.qps, "30"
          @equal dbKey.qpd, "1000"

          done 5

  "test PUT with a bad structure": ( done ) ->
    options =
      path: "/v1/key/1234"
      headers:
        "Content-Type": "application/json"
      data: JSON.stringify
        forApi: "twitter"
        qps: "hi"     # invalid
        qpd: 1000

    @apiKeyModel.create "1234", forApi: "twitter", ( err, origKey ) =>
      @isNull err
      @ok origKey

      @PUT options, ( err, res ) =>
        @equal res.statusCode, 400

        res.parseJson ( json ) =>
          @ok json
          @equal json.error.type, "ValidationError"

          done 5

  "test DELETE": ( done ) ->
    @apiKeyModel.create "1234", forApi: "twitter", ( err, origKey ) =>
      @isNull err
      @ok origKey

      @DELETE path: "/v1/key/1234", ( err, res ) =>
        @equal res.statusCode, 200

        @apiKeyModel.find "1234", ( err, dbKey ) =>
          @isNull err
          @isNull dbKey

          done 5

  "test get key range without resolution": ( done ) ->
    # create 11 keys
    fixtures = []

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          @apiKeyModel.create "key_#{i}", forApi: "twitter", cb

    async.series fixtures, ( err, newKeys ) =>
      @isUndefined err

      @GET path: "/v1/key/list/1/12", ( err, response ) =>
        @isNull err

        response.parseJson ( json ) =>
          @ok json
          @equal json.length, 10

          done 4


  "test get key range with resolution": ( done ) ->
    # create 11 keys
    fixtures = []

    for i in [ 0..10 ]
      do ( i ) =>
        fixtures.push ( cb ) =>
          @apiKeyModel.create "key_#{i}", forApi: "twitter", qps: i, qpd: i, cb

    async.parallel fixtures, ( err, newKeys ) =>
      @isUndefined err

      @GET path: "/v1/key/list/0/12?resolve=true", ( err, response ) =>
        @isNull err

        response.parseJson ( json ) =>
          @ok json

          for i in [ 0..9 ]
            name = "key_#{i}"

            @ok json[ name ]
            @equal json[ name ].qpd, i
            @equal json[ name ].qps, i
            @equal json[ name ].forApi, "twitter"

          done 43
