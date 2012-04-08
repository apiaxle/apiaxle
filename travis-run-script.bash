#!/usr/bin/env bash

set -e

export NODE_ENV=test
export MY_TWERP_OPTIONS="--exit-on-failure --runner=simple"

# proxy and api
for project in proxy api; do
  pushd ${project}

  npm install >/dev/null
  npm link ../base >/dev/null
  cake test

  popd &> /dev/null
done

# now base
cd base
npm install >/dev/null
npm link ../base >/dev/null
cake test
