#!/usr/bin/env bash

set -e

export NODE_ENV=test
export MY_TWERP_OPTIONS="--exit-on-failure --runner=simple"

# cant do proxy yet because of the tests that rely on host files being
# set.
for project in base api; do
  pushd ${project}

  echo "Installing modules..."
  npm install &>/dev/null

  if [[ ${project} != "base" ]]; then
    npm link ../base
  fi

  export MY_TWERP_OPTIONS="--exit-on-failure --runner=simple"
  cake test

  popd &> /dev/null
done
