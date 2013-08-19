class exports.PathSplitter
  constructor: ->
    @re_cache = {}

  getRegexpForDefinition: ( def ) ->
    # return the cached version if we have it
    return @re_cache[ def ] if @re_cache[ def ]

    # /animal/*/noise
    re = /\*/g

    new_def = def.replace re, "(.+?)"
    new_re = new RegExp new_def

    return ( @re_cache[ def ] = new_re )

  # definitions is the list of potential paths with placeholders in
  # them. For example:
  #     /animal/noise/*
  #
  # should match any of:
  #     /animal/noise/bark
  #     /animal/noise/yip
  #     /animal/noise/yap
  #
  # and for any of those, return the matching definition:
  #     /animal/noise/*
  matchPathDefinitions: ( path, definitions ) ->
    all_matches = []

    for definition in definitions
      re = @getRegexpForDefinition definition
      if re.exec path
        all_matches.push definition

    return all_matches
