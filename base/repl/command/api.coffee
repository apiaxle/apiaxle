_ = require "underscore"
{ Command } = require "../command"

class exports.Api extends Command
  constructor: ( app ) ->
    @model = app.model( "apiFactory" )
    super app

  delete: ( commands, cb ) ->
    id = commands.shift()
    if not id or typeof( id ) isnt "string"
      return cb new Error "Expecting an ID (string) as the first argument."

    # the fields this model supports
    props = @model.constructor.structure.properties
    keys  = _.keys( props ).sort()

    @model.find id, ( err, dbApi ) =>
      return cb err if err
      return cb new Error "'#{ id }' doesn't exist." if not dbApi

      @model.delete id, ( err ) ->
        return cb err if err

        return cb null, "'#{ id }' deleted."

  update: ( commands, cb ) ->
    id = commands.shift()
    if not id or typeof( id ) isnt "string"
      return cb new Error "Expecting an ID (string) as the first argument."

    # the fields this model supports
    props = @model.constructor.structure.properties
    keys  = _.keys( props ).sort()

    @model.find id, ( err, dbApi ) =>
      return cb err if err
      return cb new Error "'#{ id }' doesn't exist." if not dbApi

      @_mergeObjects commands, [], keys, ( err, missing, options ) =>
        return cb err if err

        @model.create id, options, ( err, dbApi ) ->
          return cb err if err

          return cb null, dbApi.data

  create: ( commands, cb ) ->
    id = commands.shift()
    if not id or typeof( id ) isnt "string"
      return cb new Error "Expecting an ID (string) as the first argument."

    # the fields this model supports
    props = @model.constructor.structure.properties
    keys  = _.keys( props ).sort()

    # these are the required_keys options
    required_keys = _.filter keys, ( k ) -> props[ k ].required
    optional_keys = _.difference keys, required_keys

    @_mergeObjects commands, required_keys, optional_keys, ( err, missing, options ) =>
      return cb err if err

      missing_string = _.keys( missing ).join ", "

      if missing_string
        return cb new Error "Missing required values: '#{ missing_string }'"

      @model.create id, options, ( err, dbApi ) ->
        return cb err if err

        return cb null, dbApi.data
