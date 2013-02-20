async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"

class exports.CountersTest extends FakeAppTest
  @empty_db_on_setup = true

  "test initialisation": ( done ) ->
    @ok @app
    @ok @model = @app.model "counters"

    @equal @model.ns, "gk:test:ct"

    done 3

  "test #apiHit": ( done ) ->
    clock = @getClock 1323892867000

    @model.apiHit "facebook", "1234", 200, ( err, [ min, hour, day, month, year ] ) =>
      @isNull err

      @equal day, 1
      @equal month, 1
      @equal year, 1

      # move on a day
      clock.addDays 1

      @model.apiHit "facebook", "1234", 200, ( err, [ min, hour, day, month, year ] ) =>
        @isNull err

        @equal day, 1
        @equal month, 2
        @equal year, 2

        done 8

  "test #getToday": ( done ) ->
    clock = @getClock 1323892867000

    @model.apiHit "facebook", "1234", 200, ( err, [ min, hour, day, month, year ] ) =>
      @isNull err
      @equal day, 1

      @model.getToday "key:1234", 200, ( err, count ) =>
        @equal count, 1

        # move on two days
        clock.addDays 2

        # meaning no calls yet
        @model.getToday "key:1234", 200, ( err, count ) =>
          @equal count, 0

          done 4

  "test #getHour": ( done ) ->
    clock = @getClock()

    @model.apiHit "facebook", "1234", 200, ( err, [ min, hour, day, month, year ] ) =>
      @isNull err

      for time in [ min, hour, day, month, year ]
        @equal time, 1

      # move on a day
      clock.addMinutes 1

      @model.apiHit "facebook", "1234", 200, ( err, [ min, hour, day, month, year ] ) =>
        @equal min, 1

        for time in [ day, month, year, hour ]
          @equal time, 2

        done 11

  "test #getThisMonth": ( done ) ->
    clock = @getClock 1323892867000

    @model.apiHit "facebook", "1234", 200, ( err, [ min, hour, day, month, year ] ) =>
      @isNull err
      @equal day, 1

      @model.getThisMonth "key:1234", 200, ( err, count ) =>
        @equal count, 1

        # move on a day
        clock.addDays 1

        @model.getThisMonth "key:1234", 200, ( err, count ) =>
          # move on a month
          clock.addMonths 1

          @equal count, 1

          # meaning no calls yet
          @model.getThisMonth "key:1234", 200, ( err, count ) =>
            @equal count, 0

            done 5

  "test #getThisYear": ( done ) ->
    #Thu Nov 1 10:09:07 2012 GMT
    clock = @getClock 1351764547

    @model.apiHit "facebook", "1234", 200, ( err, [ min, hour, day, month, year ] ) =>
      @isNull err
      @equal day, 1

      @model.getThisYear "key:1234", 200, ( err, count ) =>
        @equal count, 1

        # move on a month or so
        clock.addMonths 1

        @model.getThisYear "key:1234", 200, ( err, count ) =>
          # move on a year
          clock.addYears 1

          @equal count, 1

          # meaning no calls yet
          @model.getThisYear "key:1234", 200, ( err, count ) =>
            @equal count, 0

            done 5

  "test #getPossibleResponseTypes": ( done ) ->
    fixtures = []

    fixtures.push ( cb ) => @model.apiHit "facebook", "1234", 200, cb
    fixtures.push ( cb ) => @model.apiHit "facebook", "1234", "QpsExceededError", cb
    fixtures.push ( cb ) => @model.apiHit "facebook", "1234", "QpsExceededError", cb
    fixtures.push ( cb ) => @model.apiHit "facebook", "1234", "QpdExceededError", cb

    async.series fixtures, ( err, results ) =>
      @isNull err
      @ok results

      @model.getPossibleResponseTypes "key:1234", ( err, types ) =>
        @isNull err
        @equal types.length, 3

        @deepEqual types.sort(), [ "200", "QpdExceededError", "QpsExceededError" ]

        done 5
