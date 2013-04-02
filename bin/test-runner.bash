#!/usr/bin/env bash

set -e

while /bin/true; do
  change=$(inotifywait -qre close_write --format "%w" .)
  dir=$(echo ${change} | perl -nle 'm#\./([^/]+)# and print $1')

  if [[ -f "${dir}/Cakefile" ]]; then
    pushd "${dir}"
    cake test
    popd
  fi
done
  