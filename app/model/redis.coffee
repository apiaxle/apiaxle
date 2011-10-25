class exports.Redis
  @commands = [
    "set"
    "get"
    "incr"
    "del"
    "keys"
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
          key.unshift @ns

          @gatekeeper.redisClient[ command ]( key.join( ":" ), rest... )

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
