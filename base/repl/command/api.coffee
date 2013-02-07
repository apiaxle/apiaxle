_ = require "underscore"
{ Command } = require "../command"

class exports.Api extends Command
  constructor: ( axle ) ->
    @model = @axle.model( "apiFactory" )
    super axle

  create: ( commands, cb ) ->
    id = commands.shift()
    if not id or typeof( id ) isnt "string"
      return cb new Error "Expecting an ID (string) as the first argument."

    # the fields this model supports
    props = model.constructor.structure.properties
    keys  = _.keys( props ).sort()

    # these are the required_keys options
    required_keys = _.filter keys, ( k ) -> props[ k ].required
    optional_keys = _.difference keys, required_keys

    @_mergeObjects commands, required_keys, optional_keys, ( err, options ) ->
      return cb err if err

      model.create id, options, ( err, dbApi ) ->
        return cb err if err

        return cb null, dbApi.data
