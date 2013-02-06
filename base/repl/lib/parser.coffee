Tokenizer = require "tokenizer"

module.exports = ( str ) ->
  all        = []
  lastString = null
  assignment = false

  buildCommandStruct = ( token, type ) ->
    return if type in [ "seperator" ]

    switch type
      when assignment and "string"
        output = {}
        output[ lastString ] = token
        assignment = false
        all.push output
      when "string" then lastString = token
      when "assignment" then assignment = true
      when "command" then all.push token
      when "digit" then all.push token

  t = new Tokenizer()
  t.on "token", buildCommandStruct

  # command, or a 'bare word'
  t.addRule(/^\w+$/, "bare")

  # quoted string
  t.addRule(/^"([^"]|\\")*"$/, 'string') #"
  t.addRule(/^"([^"]|\\")*$/, 'maybe-string') #"

  # int
  t.addRule(/\d+/, "digit")

  # key=value pair
  t.addRule /^=$/, "assignment"

  # whitespace
  t.addRule /^\s+$/, "seperator"

  t.end str
  return all
