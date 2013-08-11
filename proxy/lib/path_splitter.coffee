class exports.PathSplitter
  getRegexpForDefinition: ( definition ) ->
    # /animal/:breed/noise
    #        ^^^^^^^
    re = /(?::(.+?)\b)/g

    new_def = definition.replace re, "(.+?)"
    new_re = new RegExp new_def

    return new_re

  # definitions is the list of potential paths with placeholders in
  # them. For example:
  #     /animal/noise/:noise
  #
  # should match any of:
  #     /animal/noise/bark
  #     /animal/noise/yip
  #     /animal/noise/yap
  #
  # and for any of those, return the matching definition:
  #     /animal/noise/:noise
  matchDefinitions: ( path, definitions ) ->
    all_matches = []

    for definition in definitions
      re = @getRegexpForDefinition definition
      if re.exec path
        all_matches.push definition

    return all_matches
