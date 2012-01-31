#!/usr/bin/env bash

while getopts :d OPT; do
  case $OPT in
    d|+d)
      DEBUG=1
      ;;
    *)
      echo "usage: ${0##*/} [+-d (debug)} [--] TESTS..."
      exit 2
  esac
done
shift $(( OPTIND - 1 ))
OPTIND=1

if [[ $# == 0 ]]; then
  # no tests specified, find all matching test.coffee
  TESTS=$(find test -name '*test.coffee')
else
  TESTS=${@}
fi

export NODE_PATH="$(pwd)/test"
export NODE_ENV=test

[[ -d log ]] || mkdir log

if [[ ${DEBUG} ]]; then
  node --debug-brk "${DEBUG}" $(which twerp) ${MY_TWERP_OPTIONS} ${TESTS}
else
  twerp ${MY_TWERP_OPTIONS} ${TESTS}
fi