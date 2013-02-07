_ = require "underscore"

class exports.Command
  constructor: ( @axle ) ->

  _mergeObjects: ( objects, required_keys, optional_keys, cb ) ->
    all = {}

    # converts [ "hello", "there" ] -> { hello: false, there: flase }
    required_keys_lookup = _.object( required_keys, ( false for item in required_keys ) )
    optional_keys_lookup = _.object( optional_keys, ( false for item in optional_keys ) )

    for object in objects
      if ( type = typeof( object ) ) isnt "object"
        return cb new Error "Expecting a keyvalue pair, got '#{ type }' (#{ object })"

      # copy the fields
      for k, v of object
        all[ k ] = v

        if required_keys_lookup[ k ]?
          delete required_keys_lookup[ k ]
          continue

        if optional_keys_lookup[ k ]?
          delete optional_keys_lookup[ k ]
          continue

        # if we're here it's an invalid field
        return cb new Error "I can't handle the field '#{ k }'"

    # build a string of the missing bits
    missing = _.keys( required_keys_lookup ).join ", "

    if missing
      return cb new Error "Missing required values: '#{ missing }'"

    return cb null, all
