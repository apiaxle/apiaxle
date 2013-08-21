{ Redis } = require "../redis"
{ StatCounters, StatTimers } = require "./arb_stats"

async = require "async"

class CapturePathsTimers extends StatTimers
  @smallKeyName = "captr-tmr"

class CapturePathsCounters extends StatCounters
  @smallKeyName = "captr-cntr"

class exports.CapturePaths extends Redis
  @instantiateOnStartup = true
  @smallKeyName = "captr"

  constructor: ( app ) ->
    @timer = new CapturePathsTimers app
    @counter = new CapturePathsCounters app

    super app

  log: ( api_id, key_id, keyring_ids, matches, time, cb ) ->
    all = []

    timer_multi = @timer.multi()
    counter_multi = @counter.multi()

    for match in matches
      do( match ) =>
        all.push ( cb ) => @timer.logTiming timer_multi, [ "api", api_id ], match, time, cb

        # We log several counters, one for the api, one for the key,
        # one for each keyring and combination
        all.push ( cb ) =>
          @counter.logCounter counter_multi, [ "api", api_id ], match, cb

        all.push ( cb ) =>
          @counter.logCounter counter_multi, [ "api-key", api_id, key_id ], match, cb

        # for each keyring, log the count
        for keyring in keyring_ids
          do( keyring ) =>
            all.push ( cb ) =>
              @counter.logCounter counter_multi, [ "api-keyring", api_id, keyring_id ], match, cb

    all.push ( cb ) -> timer_multi.exec cb
    all.push ( cb ) -> counter_multi.exec cb

    return async.series all, cb

  getCounters: ( namespace, matches, gran, from, to, cb ) ->
    @counter.getValues namespace, matches, gran, from, to, cb

  getTimers: ( namespace, matches, gran, from, to, cb ) ->
    @timer.getValues namespace, matches, gran, from, to, cb
