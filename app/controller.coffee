{ CompanyUnknown } = require "../lib/error"

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

  company: ( req, res, next ) =>
    # no subdomain means no company
    if not req.subdomain
      return next new CompanyUnknown "No company specified (via subdomain)"

    @gatekeeper.model( "company" ).find req.subdomain, ( err, company ) ->
      return next err if err

      if company
        req.company = company
        return next()

      # no company found
      return next new CompanyUnknown "'#{ req.subdomain }' is not a company known to us."
