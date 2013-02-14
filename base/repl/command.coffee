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

    return cb null, required_keys_lookup, all

class exports.ModelCommand extends exports.Command
  constructor: ( @app ) ->
    super app

  model: ( ) ->
    return @_model if @_model
    return ( @_model = @app.model( @constructor.modelName ) )

  modelProps: ( ) ->
    ( @model().constructor.structure.properties or [] )

  _getId: ( commands, cb ) ->
    id = commands.shift()
    if not id or typeof( id ) isnt "string"
      return cb new Error "Expecting an ID (string) as the first argument."

    return cb null, id

  list: ( [ from, to, rest... ], cb ) ->
    @model().range ( from or 0 ), ( to or 1000 ), cb

  find: ( commands, cb ) ->
    @_getId commands, ( err, id ) =>
      return cb err if err

      @model().find id, ( err, dbApi ) =>
        return cb err if err
        return cb null, dbApi.data

  delete: ( commands, cb ) ->
    @_getId commands, ( err, id ) =>
      return cb err if err

      keys = _.keys( @modelProps() ).sort()
      @model().find id, ( err, dbApi ) =>
        return cb err if err
        return cb new Error "'#{ id }' doesn't exist." if not dbApi

        @model().delete id, ( err ) ->
          return cb err if err
          return cb null, "'#{ id }' deleted."

  update: ( commands, cb ) ->
    @_getId commands, ( err, id ) =>
      # the fields this model supports
      keys = _.keys( @modelProps() ).sort()

      @model().find id, ( err, dbApi ) =>
        return cb err if err
        return cb new Error "'#{ id }' doesn't exist." if not dbApi

        @_mergeObjects commands, [], keys, ( err, missing, options ) =>
          return cb err if err

          @model().create id, options, ( err, dbApi ) ->
            return cb err if err
            return cb null, dbApi.data

  create: ( commands, cb ) ->
    @_getId commands, ( err, id ) =>
      # the fields this model supports
      keys  = _.keys( @modelProps() ).sort()

      # these are the required_keys options
      required_keys = _.filter keys, ( k ) => @modelProps()[ k ].required
      optional_keys = _.difference keys, required_keys

      @_mergeObjects commands, required_keys, optional_keys, ( err, missing, options ) =>
        return cb err if err

        missing_string = _.keys( missing ).join ", "

        if missing_string
          return cb new Error "Missing required values: '#{ missing_string }'"

        @model().create id, options, ( err, dbApi ) ->
          return cb err if err
          return cb null, dbApi.data
