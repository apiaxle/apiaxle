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
for project in base api proxy; do
  pushd ${project}

  echo "Installing modules..."
  silence-or-loud-on-error npm install

  if [[ ${project} != "base" ]]; then
    echo "Linking base..."
    silence-or-loud-on-error npm link ../base
  fi

  export MY_TWERP_OPTIONS="--exit-on-failure --runner=simple"
  cake test

  popd &> /dev/null
done
