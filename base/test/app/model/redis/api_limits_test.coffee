# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"
{ ApiLimits }   = require "../../../../app/model/redis/api_limits"
{ QpsExceededError, QpdExceededError } = require "../../../../lib/error"

class exports.QpdTest extends FakeAppTest
  @empty_db_on_setup = true

  "test keys": ( done ) ->
    @ok @app,
      "application is defined"

    @ok model = @app.model "apilimits"

    @equal model.ns, "gk:test:al"

    done 3

  "test first apiHit": ( done ) ->
    model = @app.model "apilimits"

    model.apiHit "1234", 2, 20, ( err, [ currentQpd, currentQps ] ) =>
      @ok not err
      @equal currentQps, 1
      @equal currentQpd, 19

      done 3

  "test second apiHit": ( done ) ->
    model = @app.model "apilimits"

    # we need to stub the keys because there's a chance we'll tick
    # over to the next second/day
    qpsKeyStub = @getStub ApiLimits::, "qpsKey", -> "qpsTestKey"
    qpdKeyStub = @getStub ApiLimits::, "qpdKey", -> "qpdTestKey"

    model.apiHit "1234", 2, 20, ( err, [ currentQpd, currentQps ] ) =>
      @ok not err
      @equal currentQps, 1
      @equal currentQpd, 19

      @ok qpsKeyStub.called
      @ok qpdKeyStub.called

      model.apiHit "1234", 2, 20, ( err, [ currentQpd, currentQps ] ) =>
        @ok not err
        @equal currentQps, 0
        @equal currentQpd, 18

        @ok qpsKeyStub.called
        @ok qpdKeyStub.called

        done 10

  "test third and errornous apiHit": ( done ) ->
    model = @app.model "apilimits"

    # we need to stub the keys because there's a chance we'll tick
    # over to the next second/day
    qpsKeyStub = @getStub ApiLimits::, "qpsKey", -> "qpsTestKey"
    qpdKeyStub = @getStub ApiLimits::, "qpdKey", -> "qpdTestKey"

    model.apiHit "1234", 2, 20, ( err, [ currentQpd, currentQps ] ) =>
      @ok not err
      @equal currentQps, 1
      @equal currentQpd, 19

      @ok qpsKeyStub.called
      @ok qpdKeyStub.called

      model.apiHit "1234", 2, 20, ( err, [ currentQpd, currentQps ] ) =>
        @ok not err
        @equal currentQps, 0
        @equal currentQpd, 18

        @ok qpsKeyStub.called
        @ok qpdKeyStub.called

        model.apiHit "1234", 2, 20, ( err, [ currentQpd, currentQps ] ) =>
          @ok qpsKeyStub.called
          @ok qpdKeyStub.called

          @ok err instanceof QpsExceededError

          done 13

  "test apiHit returns qpd and qps when qpd is unlimited": ( done ) ->
    model = @app.model "apilimits"

    # we need to stub the keys because there's a chance we'll tick
    # over to the next second/day
    qpsKeyStub = @getStub ApiLimits::, "qpsKey", -> "qpsTestKey"
    qpdKeyStub = @getStub ApiLimits::, "qpdKey", -> "qpdTestKey"

    model.apiHit "1234", 2, -1, ( err, limits ) =>
      @ok not err
      @equal limits.length, 2

      done 2
