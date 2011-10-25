class exports.Redis
  @commands = [
    "expire"
    "set"
    "get"
    "incr"
    "del"
    "keys"
    "ttl"
  ]

  constructor: ( @gatekeeper ) ->
    env = @gatekeeper.constructor.env
    name = @constructor.name.toLowerCase()

    @ns = "gk:#{ env }:#{ name }:"

    # build up the commands in `@commands`, making sure they use the
    # corrent namespace. Rather than a string for key they take an
    # array of strings which are joined later.
    for command in @constructor.commands
      do ( command ) =>
        @[ command ] = ( key, rest... ) =>
          @gatekeeper.redisClient[ command ]( @getKey( key ), rest... )

  getKey: ( parts ) ->
    parts.unshift @ns
    return parts.join ":"

  # Clear the keys associated with this model (taking into account the
  # namespace). It's for tests, not for use in production code.
  flush: ( cb ) ->
    multi = @gatekeeper.redisClient.multi()

    # loop over all of the keys deleting them one by one :/
    @keys [ "*" ], ( err, keys ) ->
      return cb err if err

      for key in keys
        multi.del key, ( err, res ) ->
          return cb err if err

      multi.exec cb