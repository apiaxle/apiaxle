# This code is covered by the GPL version 3.
# Copyright 2011-2013 Philip Jackson.
async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"
{ ApiLimits }   = require "../../../../app/model/redis/api_limits"
{ QpsExceededError, QpmExceededError, QpdExceededError } = require "../../../../lib/error"

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

    model.apiHit "1234", 2, 10, 20, ( err, [ currentQpd, currentQpm, currentQps ] ) =>
      @ok not err
      @equal currentQps, 1
      @equal currentQpm, 9
      @equal currentQpd, 19

      done 4

  "test second apiHit": ( done ) ->
    model = @app.model "apilimits"

    # we need to stub the keys because there's a chance we'll tick
    # over to the next second/day
    qpsKeyStub = @getStub ApiLimits::, "qpsKey", -> "qpsTestKey"
    qpmKeyStub = @getStub ApiLimits::, "qpmKey", -> "qpmTestKey"
    qpdKeyStub = @getStub ApiLimits::, "qpdKey", -> "qpdTestKey"

    model.apiHit "1234", 2, 10, 20, ( err, [ currentQpd, currentQpm, currentQps ] ) =>
      @ok not err
      @equal currentQps, 1
      @equal currentQpm, 9
      @equal currentQpd, 19

      @ok qpsKeyStub.called
      @ok qpmKeyStub.called
      @ok qpdKeyStub.called

      model.apiHit "1234", 2, 10, 20, ( err, [ currentQpd, currentQpm, currentQps ] ) =>
        @ok not err
        @equal currentQps, 0
        @equal currentQpm, 8
        @equal currentQpd, 18

        @ok qpsKeyStub.called
        @ok qpmKeyStub.called
        @ok qpdKeyStub.called

        done 14

  "test third and errornous apiHit": ( done ) ->
    model = @app.model "apilimits"

    # we need to stub the keys because there's a chance we'll tick
    # over to the next second/day
    qpsKeyStub = @getStub ApiLimits::, "qpsKey", -> "qpsTestKey"
    qpmKeyStub = @getStub ApiLimits::, "qpmKey", -> "qpmTestKey"
    qpdKeyStub = @getStub ApiLimits::, "qpdKey", -> "qpdTestKey"

    model.apiHit "1234", 2, 10, 20, ( err, [ currentQpd, currentQpm, currentQps ] ) =>
      @ok not err
      @equal currentQps, 1
      @equal currentQpm, 9
      @equal currentQpd, 19

      @ok qpsKeyStub.called
      @ok qpmKeyStub.called
      @ok qpdKeyStub.called

      model.apiHit "1234", 2, 10, 20, ( err, [ currentQpd, currentQpm, currentQps ] ) =>
        @ok not err
        @equal currentQps, 0
        @equal currentQpm, 8
        @equal currentQpd, 18

        @ok qpsKeyStub.called
        @ok qpmKeyStub.called
        @ok qpdKeyStub.called

        model.apiHit "1234", 2, 10, 20, ( err, [ currentQpd, currentQpm, currentQps ] ) =>
          @ok qpsKeyStub.called
          @ok qpmKeyStub.called
          @ok qpdKeyStub.called

          @ok err instanceof QpsExceededError

          done 18

  "test apiHit returns qpd and qps when qpd is unlimited": ( done ) ->
    model = @app.model "apilimits"

    # we need to stub the keys because there's a chance we'll tick
    # over to the next second/day
    qpsKeyStub = @getStub ApiLimits::, "qpsKey", -> "qpsTestKey"
    qpmKeyStub = @getStub ApiLimits::, "qpmKey", -> "qpmTestKey"
    qpdKeyStub = @getStub ApiLimits::, "qpdKey", -> "qpdTestKey"

    model.apiHit "1234", 2, 10, -1, ( err, limits ) =>
      @ok not err
      @equal limits.length, 3

      done 2
