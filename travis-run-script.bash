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

# cant do proxy yet because of the tests that rely on host files being
# set.
for project in base api proxy repl; do
  pushd ${project}

  # we want to run the development base, not the one in npm!
  if [[ ${project} != "base" ]]; then
    echo "Installing base..."
    silence-or-loud-on-error npm link ../base
  fi
  
  if [[ ${project} == "repl" ]]; then
    echo "Installing api..."
    silence-or-loud-on-error npm link ../api
  fi

  echo "Installing modules..."
  silence-or-loud-on-error npm install

  TESTS=$(find test -name '*test.js')

  # circleci seems to need this
  export PATH="node_modules/.bin:${PATH}"

  export MY_TWERP_OPTIONS="--exit-on-failure --runner=simple"
  if ! istanbul cover $(which twerp) ${MY_TWERP_OPTIONS} ${TESTS}; then
    exit 1
  fi

  cake "js:clean" &>/dev/null

  # lint (fails on error)
  cake lint || exit 1

  popd &> /dev/null
done
