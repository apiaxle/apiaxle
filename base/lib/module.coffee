# A class that provides a mixin type interface.
moduleKeywords = [ "extended", "included" ]

class exports.Module
  @extend: ( obj ) ->
    for key, value of obj when key not in moduleKeywords
      @[ key ] = value

    obj.extended?.apply @
    return @

  @include: ( obj ) ->
    for key, value of obj when key not in moduleKeywords
      @::[ key ] = value

    obj.included?.apply @
    return @
