Tokenizer = require "tokenizer"

module.exports = ( str ) ->
  all        = []
  assignment = false
  allpairs   = {}

  buildCommandStruct = ( token, type ) ->
    return if type in [ "seperator" ]


    if type is "digit"
      all.push parseInt( token )

    if type in [ "string", "bare" ]
      # strip the starting and ending " from the string
      token = token.replace /(?:^['"]|["']$)/g, "" if type is "string"

      all.push token

    # the previous string/bare was meant to be a key in a hash
    if assignment
      val = all.pop()
      key = all.pop()
      allpairs[ key ] = val
      assignment = false
      return

    if type is "assignment"
      assignment = true

  t = new Tokenizer()
  t.on "token", buildCommandStruct

  # int
  t.addRule(/^(\d+)$/, "digit")

  # whitespace
  t.addRule /^\s+$/, "seperator"

  # command, or a 'bare word'
  t.addRule(/^(\w+)$/, "bare")

  # quoted string
  t.addRule(/^"([^"]|\\")*"$/, 'string') #"
  t.addRule(/^"([^"]|\\")*$/, 'maybe-string') #"

  t.addRule(/^'([^']|\\')*'$/, 'string') #'
  t.addRule(/^'([^']|\\')*$/, 'maybe-string') #'

  # key=value pair
  t.addRule /^=$/, "assignment"

  t.end str
  return [ all, allpairs ]
