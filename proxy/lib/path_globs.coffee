_ = require "lodash"
url = require "url"

class exports.PathGlobs
  constructor: ->
    @def_parse_cache = {}
    @def_re_cache = {}

  getRegexpForDefinition: ( def ) ->
    # /animal/*/noise
    re = /\*/g

    new_def = def.replace re, "([^$/?&]+)"
    new_re = new RegExp "^#{ new_def }" # note the anchor

    return new_re

  doQueryParamsMatch: ( wanted, got ) ->
    for expected_key, expected_value of wanted
      if expected_value is "*" and got[expected_key]?
        continue

      if got[expected_key] isnt expected_value
        return false

    return true

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
  matchPathDefinitions: ( path, query_params, definitions ) ->
    all_matches = []

    for definition in definitions
      # firstly check the query params, we need to parse the
      # definition itself to get the query param hash.

      # Cache the parsing of the definition as it's going to be
      # expensive.
      our_definitions = if @def_parse_cache[definition]?
        @def_parse_cache[definition]
      else
        @def_parse_cache[definition] = url.parse( definition, true )

      continue unless @doQueryParamsMatch our_definitions.query, query_params

      # Cache this RE too
      re = if @def_re_cache[definition]?
        @def_re_cache[definition]
      else
        @def_re_cache[definition] = @getRegexpForDefinition our_definitions.pathname

      if re.exec path
        all_matches.push definition

    return all_matches
