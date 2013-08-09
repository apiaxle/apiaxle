class exports.PathSplitter
  hashifyArray: ( arr ) ->
    hash = []
    name = ""

    for part, i in arr
      name += "#{ part }"
      name += "/" if i isnt arr.length

      hash.push name

    return hash

  parse: ( parsed_url ) ->
    path = parsed_url.path

    # strip leading and trailing slashes and split
    path_array = path.replace( /^\/|\/$/g, "" ).split "/"
    return @hashifyArray path_array
