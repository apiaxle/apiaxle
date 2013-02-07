_ = require "underscore"
{ Command } = require "../command"

class exports.Api extends Command
  constructor: ( axle ) ->
    @model = axle.model( "apiFactory" )
    super axle

  update: ( commands, cb ) ->
    id = commands.shift()
    if not id or typeof( id ) isnt "string"
      return cb new Error "Expecting an ID (string) as the first argument."

    # the fields this model supports
    props = @model.constructor.structure.properties
    keys  = _.keys( props ).sort()

    @_mergeObjects commands, null, null, ( err, options ) =>
      return cb err if err

      @model.update id, options, ( err, dbApi ) ->
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

      missing = _.keys(  ).join ", "

      if missing
        return cb new Error "Missing required values: '#{ missing }'"

      @model.create id, options, ( err, dbApi ) ->
        return cb err if err

        return cb null, dbApi.data
