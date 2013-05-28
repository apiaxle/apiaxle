#!/usr/bin/env bash

set -e

for project in repl api proxy base; do
  cd $project

  if grep "\"${1}\"" package.json >/dev/null 2>&1; then
    echo "${project} has ${1}"

    npm remove --save "${1}"
    npm install --save "${1}"
  fi

  cd - >/dev/null
done
