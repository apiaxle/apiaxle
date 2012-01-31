#!/usr/bin/env bash

set -e

DEVELOPER=0
while getopts :d OPT; do
  case $OPT in
    d|+d)
      DEVELOPER=1
      ;;
    *)
      echo "usage: ${0##*/} [+-d}"
      exit 2
  esac
done
shift $(( OPTIND - 1 ))
OPTIND=1

# allow a develope to setup and be ready to hack
if [[ "${DEVELOPER}" ]]; then
  main="git@github.com:philjackson/apiaxle.git"
  base="git@github.com:philjackson/apiaxle.base.git"
  api="git@github.com:philjackson/apiaxle.api.git"
else
  main="git://github.com/philjackson/apiaxle.git"
  base="git://github.com/philjackson/apiaxle.base.git"
  api="git://github.com/philjackson/apiaxle.api.git"
fi

main_name="$(basename ${main%%.git})"
base_name="$(basename ${base%%.git})"
api_name="$(basename ${api%%.git})"

function which-or-die {
  for command in "${@}"; do
    if ! which "${command}"; then
      echo "The '${command}' program is missing please install and try again!"
      exit 1
    fi
  done
}

function save-excurstion {
  dir="${1}"; shift

  pwd
  pushd "${dir}"
  ${@}
  popd
}

which-or-die node npm

# clone the repos
for f in "${base}" "${main}" "${api}"; do
  git clone "${f}"
done

# have npm do its thing
for d in "${main_name}" "${api_name}" "${base_name}"; do
  save-excurstion "${d}" npm install
done

# link the base library to api and main
for d in "${main_name}" "${api_name}"; do
  save-excurstion "${d}" npm link "../${base_name}"
done
