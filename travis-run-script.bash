#!/usr/bin/env bash

set -e

export NODE_ENV=test
export MY_TWERP_OPTIONS="--exit-on-failure --runner=simple"

# cant do proxy yet because of the tests that rely on host files being
# set.
for project in api; do
  pushd ${project}

  npm install
  npm link ../base
  cake test

  popd &> /dev/null
done

# now base
cd base
npm install
npm link ../base
cake test
