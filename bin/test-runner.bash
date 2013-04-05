#!/usr/bin/env bash

set -e

while /bin/true; do
  change=$(inotifywait -qre close_write --format "%w %f" .)
  dir=$(echo ${change} | perl -nle 'm#\./([^/]+)# and print $1')

  # only if there's a cakefile in the directory
  if [[ ! -f "${dir}/Cakefile" ]]; then
    continue
  fi

  # not on emacs swap files
  if echo "${change}" | egrep '#$' &>/dev/null; then
    continue
  fi

  # not on log files
  if echo "${change}" | egrep '\.log$' &>/dev/null; then
    continue
  fi

  echo "valid enough change: ${change}"

  pushd "${dir}"
  cake test || echo "Failed."
  popd
done
  