{ StatCounters } = require "./arb_stats"

class exports.CapturePaths extends StatCounters
  @instantiateOnStartup = true
  @smallKeyName = "captr"
