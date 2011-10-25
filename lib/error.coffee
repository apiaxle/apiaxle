class exports.GatekeeperError extends Error
  constructor: ( msg, @options ) ->
    @name = arguments.callee.name
    @message = msg

    @details = @options?.details
    @jsonStatus = ( @options?.status or 500 )
    @htmlStatus = ( @options?.htmlStatus or 200 )
    @asJson = ( @options?.asJson or false )

    Error.captureStackTrace @, arguments.callee

class exports.NotFoundError extends exports.GatekeeperError
  constructor: ( msg, @options ) ->
    super
    @jsonStatus = 404
    @htmlStatus = 404

class exports.InvalidContentType extends exports.GatekeeperError
  constructor: ( msg, @options ) ->
    super
    @jsonStatus = 400

class exports.DbError extends exports.GatekeeperError
class exports.NotImplementedError extends exports.GatekeeperError

class exports.YoutubeApiError extends exports.GatekeeperError
  constructor: ( msg, @options ) ->
    super
    @jsonStatus = 400

class exports.UserNotLoggedIn extends exports.GatekeeperError
  constructor: ( msg, @options ) ->
    super
    @jsonStatus = 401

class exports.ValidationError extends exports.GatekeeperError
  constructor: ( msg, @options ) ->
    super
    @jsonStatus = 400

class exports.FacebookError extends exports.GatekeeperError
  constructor: ( msg, @options ) ->
    super
    @jsonStatus = 400
