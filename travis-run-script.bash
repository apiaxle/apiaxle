#!/usr/bin/env bash

set -e

export NODE_ENV=test
export MY_TWERP_OPTIONS="--exit-on-failure --runner=simple"

# cant do proxy yet because of the tests that rely on host files being
# set.
for project in api base; do
  pushd ${project}

  echo "Installing modules..."
  npm install &>/dev/null

  if [[ ${project} -ne "base" ]]; then
    echo "Linking base..."
    npm link ../base &>/dev/null
  fi

  export MY_TWERP_OPTIONS="--exit-on-failure --runner=simple"
  cake test

  popd &> /dev/null
done
