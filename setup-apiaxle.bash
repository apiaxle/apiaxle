#!/usr/bin/env bash

set -e

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

git clone git@github.com:philjackson/apiaxle.git

cd apiaxle

# have npm do its thing
for d in base proxy api; do
  save-excurstion "${d}" npm install
done

# link the base library to api and main
for d in proxy api; do
  save-excurstion "${d}" npm link "../base"
done
