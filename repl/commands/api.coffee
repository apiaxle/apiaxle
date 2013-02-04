{ ApiaxleProxy } = require "../../proxy/apiaxle_proxy"

class exports.Api
  constructor: ( @alxe, @toplevel_loop ) ->

  create: ( commands, topLevelInput ) ->
    switch commands.length
      when 2 then [ name, options ] = args
      when 1 then [ name ] = args
      else name = "bucket-#{ @keys.pop() }"

    topLevelInput()
