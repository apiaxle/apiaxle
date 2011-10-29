{ ApiUnknown, ApiKeyError } = require "../lib/error"

_ = require "underscore"

class exports.Controller
  @assetMap =
    follow:
      js: [ "follow.js" ]
      css: [ ]
      templates: [ ]

    posts:
      js: [ "post.js" ]
      css: [ ]
      templates: [ "post-and-comment-templates" ]

    comments:
      js: [ "comment.js" ]
      css: [ ]
      templates: [ "post-and-comment-templates" ]

  constructor: ( @gatekeeper, @cleanPath ) ->
    if not verb = @constructor.verb
      throw new Error "'#{ @constructor.name } needs a http verb."

    @gatekeeper.app[ verb ] @path(), @middleware(), ( req, res, next ) =>
      @execute req, res, next

  middleware: ( ) -> [ ]

  assets: ( ) -> [ ]

  path: ( ) -> "/#{ @cleanPath }"

  apiJson: ( res, structure, rest... ) ->
    if structure?._id
      structure.id = structure._id
      delete structure._id

    res.json structure, rest...

  # middleware

  api: ( req, res, next ) =>
    # no subdomain means no api
    if not req.subdomain
      return next new ApiUnknown "No api specified (via subdomain)"

    @gatekeeper.model( "api" ).find req.subdomain, ( err, api ) ->
      return next err if err

      if api
        req.api = api
        return next()

      # no api found
      return next new ApiUnknown "'#{ req.subdomain }' is not known to us."

  apiKey: ( req, res, next ) =>
    key = req.query.api_key

    if not key
      return next new Error "No api_key specified."

    @gatekeeper.model( "apiKey" ).find key, ( err, keyDetails ) ->
      return next err if err

      if keyDetails?.forApi isnt req.subdomain
        return next new ApiKeyError "'#{ key }' is not a valid key for '#{ req.subdomain }'"

      req.key = keyDetails

      next()
