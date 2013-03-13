#!/usr/bin/env bash

set -e

export NODE_ENV=test
export MY_TWERP_OPTIONS="--exit-on-failure --runner=simple"

# only output anything if a command fails
function silence-or-loud-on-error {
  output=$(${@} 2>&1)

  if [[ ${?} != 0 ]]; then
    echo "${output}"
  fi
}

# cant do proxy yet because of the tests that rely on host files being
# set.
for project in base api proxy repl; do
  pushd ${project}

  echo "Installing modules..."
  silence-or-loud-on-error npm install

  # we want to run the development base, not the one in npm!
  if [[ ${project} != "base" ]]; then
    echo "Linking base..."
    silence-or-loud-on-error npm link ../base
  fi
  
  if [[ ${project} == "repl" ]]; then
    echo "Linking api..."
    silence-or-loud-on-error npm link ../api
  fi

  TESTS=$(find test -name '*test.js')

  export MY_TWERP_OPTIONS="--exit-on-failure --runner=simple"
  istanbul cover $(which twerp) ${MY_TWERP_OPTIONS} ${TESTS}

  popd &> /dev/null
done
