{ Redis } = require "../redis"

class exports.User extends Redis
  @instantiateOnStartup = true
