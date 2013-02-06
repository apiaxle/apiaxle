_ = require "underscore"
{ Command } = require "../command"

class exports.Api extends Command
  create: ( commands, topLevelInput ) ->
    console.log( commands )

    model = @axle.model( "apiFactory" )

    # the fields this model supports
    props = model.constructor.structure.properties
    keys  = _.keys( props ).sort()

    # these are the required_keys options
    required_keys = _.filter keys, ( k ) -> props[ k ].required_keys

    # slurp them up
    input = {}
    for field in required_keys
      if not value = commands.shift()
        throw Error "#{ field } is a required value."

      input[ field ] = value

    # now the unrequired_keys options
    unrequired_keys = _.difference keys, required_keys

    console.log( unrequired_keys )

    topLevelInput()
