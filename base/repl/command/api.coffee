_ = require "underscore"
{ Command } = require "../command"

class exports.Api extends Command
  create: ( commands, topLevelInput ) ->
    model = @axle.model( "apiFactory" )

    id = commands.shift()
    if not id or typeof( id ) isnt "string"
      throw new Error "Expecting an ID (string) as the first argument."

    # the fields this model supports
    props = model.constructor.structure.properties
    keys  = _.keys( props ).sort()

    # these are the required_keys options
    required_keys = _.filter keys, ( k ) -> props[ k ].required
    optional_keys = _.difference keys, required_keys

    all = @_mergeObjects commands, required_keys, optional_keys

    topLevelInput()
