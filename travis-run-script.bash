#!/usr/bin/env bash

export NODE_ENV=test
export MY_TWERP_OPTIONS="--exit-on-failure --runner=simple"

# only output anything if a command fails
function silence-or-loud-on-error {
  output=$(${@} 2>&1)

  if [[ ${?} != 0 ]]; then
    echo "${output}"
    exit ${?}
  fi
}

echo "Installing istanbul/coffee..."
silence-or-loud-on-error npm install -g istanbul coffee-script

make coverage
