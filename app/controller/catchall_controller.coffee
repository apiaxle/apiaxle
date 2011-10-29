{ Controller } = require "../controller"

class exports.RootController extends Controller
  @verb: "get"

  path: ( ) -> "*"

  middleware: -> [ @company ]

  execute: ( req, res, next ) ->
    res.json
      one: req.subdomain
