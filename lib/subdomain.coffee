module.exports = ( gatekeeper ) ->
  ( req, res, next ) ->
    # if we're called from a subdomain then let req know
    if parts = /^(.+?)\./.exec req.headers.host
      subdomain = parts[0]

      gatekeeper.redisClient.hgetall subdomain[0]


    next()
