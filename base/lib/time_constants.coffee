# Some rough constants for opertation where precision doesn't matter
# too much.

SECOND = 1
MINUTE = SECOND * 60
HOUR = MINUTE * 60
DAY = HOUR * 24
WEEK = DAY * 7
YEAR = WEEK * 52

module.exports =
  seconds: ( num=1 ) -> SECOND * num
  minutes: ( num=1 ) -> MINUTE * num
  hours: ( num=1 ) -> HOUR * num
  days: ( num=1 ) -> DAY * num
  weeks: ( num=1 ) -> WEEK * num
  years: ( num=1 ) -> YEAR * num
