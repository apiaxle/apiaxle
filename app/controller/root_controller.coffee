{ Controller } = require "../controller"

class exports.RootController extends Controller
  @verb: "get"

  path: ( ) -> "/"

  execute: ( req, res, next ) ->
    console.log( req.subdomain )

    res.json
      one: req.subdomain
