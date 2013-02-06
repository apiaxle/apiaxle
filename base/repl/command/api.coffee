_ = require "underscore"
{ Command } = require "../command"

class exports.Api extends Command
  _mergeObjects: ( objects, required_keys, optional_keys ) ->
    all = {}

    # converts [ "hello", "there" ] -> { hello: false, there: flase }
    required_keys_lookup = _.object( required_keys, ( false for item in required_keys ) )
    optional_keys_lookup = _.object( optional_keys, ( false for item in optional_keys ) )

    for object in objects
      if ( type = typeof( object ) ) isnt "object"
        throw new Error "Expecting a keyvalue pair, got '#{ type }' (#{ object })"

      # copy the fields
      for k, v of object
        required_keys_lookup[ k ] = true if required_keys_lookup[ k ]?
        optional_keys_lookup[ k ] = true if optional_keys_lookup[ k ]?

        all[ k ] = v

    # this can't be the best way...
    missing = _.chain( required_keys_lookup )
               .pairs()
               .filter( ([ name, value ]) -> not value )
               .object()
               .keys()
               .value()
               .join ", "

    if missing
      throw new Error "Missing required values: '#{ missing }'"

    return all

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
