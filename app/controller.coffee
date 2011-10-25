{ UserNotLoggedIn, NotImplementedError } = require "../lib/error"

_ = require "underscore"

assetMap =
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

class exports.Controller
  constructor: ( @gatekeeper, @cleanPath ) ->
    if not verb = @constructor.verb
      throw new Error "'#{ @constructor.name } needs a http verb."

    @locals = { }
    @locals.assets = @_buildAssets()

    @gatekeeper.app[ verb ] @path(), @middleware(), ( @req, @res, next ) =>
      @execute next

  middleware: ( ) -> [ ]

  assets: ( ) -> [ ]

  path: ( ) -> "/#{ @cleanPath }"

  _buildAssets: ( ) ->
    assets =
      js: [ ]
      css: [ ]
      templates: [ ]

    # now let the view know which assets it needs
    for asset in @assets()
      for type in [ "js", "css", "templates" ]
        if assetMap[ asset ]?[ type ]?
          for file in assetMap[ asset ][ type ]
            assets[ type ].push file

    return assets

  render: ( template, options, rest... ) ->
    # merge in the locals
    _.extend options.locals, @locals

    @res.render template, options, rest...

  json: ( structure, rest... ) ->
    if structure?._id
      structure.id = structure._id
      delete structure._id

    @res.json structure, rest...

  # middleware

  # Simply save the current location. When a controller needs to
  # redirect then it can use the cookie stored in `loc`. If a controller
  # doesn't want another to redirect here then it shouldn't include this
  # piece of middleware.
  saveLoc: ( req, res, next ) ->
    # avoid logging out if that what might happen
    url = if /logout=./.exec req.url
      "/"
    else
      req.url

    res.signedCookie "loc", url,
      path: "/"
      expires: new Date( Date.now() + 9000000 )

    next()

  # Read the "loc" cookie, return its contents. See `saveLoc` above
  # for an explanation.
  lastLoc: ( req ) -> req.cookies.loc

  _getUser: ( req, cb ) ->
    # user's already set, don't waste a db lookup
    return cb null, req.loggedinUser if req.loggedinUser?

    # "lu" = "loggedin user"
    lu = req.cookies.lu

    # no cookie means no user
    return cb null, null unless lu

    # it's possible a user is looking at their own feed and therefore
    # the :username middleware (defined in app.coffee) has done its
    # thing. We don't want to make the extra call so skip it.
    if req.user?._id.toString() is lu
      return cb null, req.user

    # valid signed cookie. Do the lookup
    model = @gatekeeper.model( "users" )
    model.findOneById model.stringToId( lu ), cb

  # Append the currently loggedin user (if there is one) to `req`.
  getLoggedinUser: ( req, res, next ) =>
    return next() if req.loggedinUser?

    @_getUser req, ( err, userDetails ) ->
      return next err if err

      req.loggedinUser = userDetails

      return next()

  # Pass exception if user isn't loggedin. Otherwise, put the user on
  # `req` as with getUser.
  shouldBeLoggedIn: ( errAsJson ) =>
    ( req, res, next ) =>
      @_getUser req, ( err, userDetails ) ->
        return next err if err

        if not req.loggedinUser = userDetails
          return next new UserNotLoggedIn "Must be logged in.",
            asJson: ( errAsJson or false )

        return next()

  # Fill in req.following.
  isFollowing: ( req, res, next ) =>
      req.following or= { }

      @_getUser req, ( err, userDetails ) =>
        return next err if err

        if not otherUser = req.user
          return next()

        model = @gatekeeper.model "relationships"
        model.isRelated req.loggedinUser, otherUser, ( err, dbRel ) ->
          return next err if err

          req.following[ otherUser.username ] = dbRel?

          return next()
