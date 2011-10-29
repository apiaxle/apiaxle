module.exports = ( gatekeeper ) ->
  ( req, res, next ) ->
    # if we're called from a subdomain then let req know
    if parts = /^(.+?)\.api\./.exec req.headers.host
      req.subdomain = parts[1]

    next()
