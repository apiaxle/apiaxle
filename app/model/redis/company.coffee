{ Redis } = require "../redis"

class exports.Company extends Redis
  @instantiateOnStartup = true
