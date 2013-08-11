class exports.PathSplitter
  hashifyArray: ( arr ) ->
    hash = []
    name = ""

    for part, i in arr
      name += "#{ part }"
      name += "/" if i isnt arr.length

      hash.push name

    return hash

  # escapeStringForRegexp: ( str ) ->
  #   str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&");

  getRegexpForDefinition: ( definition ) ->
    re = /(?::(.+?)\b)/g

    matches = definition.match re
    return [ null, null ] if not matches

    new_def = definition.replace re, "(.+?)"
    new_re = new RegExp new_def

    return [ new_re, matches ]

  # definitions is the list of potential paths with placeholders in
  # them. For example:
  #     /animal/noise/:noise
  # should match any of:
  #     /animal/noise/bark
  #     /animal/noise/yip
  #     /animal/noise/yap
  # and for any of those, return the matching definition:
  #     /animal/noise/:noise
  parse: ( parsed_url, definitions ) ->
    path = parsed_url.path

    # strip leading and trailing slashes and split
    path_array = path.replace( /^\/|\/$/g, "" ).split "/"
    return @hashifyArray path_array
