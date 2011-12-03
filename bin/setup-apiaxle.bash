#!/usr/bin/env bash

set -e

MAIN="git://github.com/philjackson/apiaxle.git"
BASE="git://github.com/philjackson/apiaxle.base.git"
API="git://github.com/philjackson/apiaxle.api.git"

MAIN_NAME="$(basename ${MAIN%%.git})"
BASE_NAME="$(basename ${BASE%%.git})"
API_NAME="$(basename ${API%%.git})"

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
for f in "${BASE}" "${MAIN}" "${API}"; do
  git clone "${f}"
done

# have npm do its thing
for d in "${MAIN_NAME}" "${API_NAME}" "${BASE_NAME}"; do
  save-excurstion "${d}" npm install
done

# link the base library to api and main
for d in "${MAIN_NAME}" "${API_NAME}"; do
  save-excurstion "${d}" npm link "../${BASE_NAME}"
done
