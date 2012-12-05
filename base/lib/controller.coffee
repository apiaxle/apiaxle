class exports.Controller
  constructor: ( @app, @cleanPath ) ->
    if not verb = @constructor.verb
      throw new Error "'#{ @constructor.name } needs a http verb."

    @app.app[ verb ] @path(), @middleware(), ( req, res, next ) =>
      @execute req, res, next

  middleware: ( ) -> []

  path: ( ) -> "/#{ @cleanPath }"
