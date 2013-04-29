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

echo "Installing istanbul..."
silence-or-loud-on-error npm install -g istanbul

echo "Installing coffee-script..."
silence-or-loud-on-error npm install -g coffee-script

make link coverage
