#!/usr/bin/env bash

set -e

function which-or-die {
  for command in "${@}"; do
    if ! which "${command}"; then
      echo "The '${command}' program is missing please install and try again!"
      exit 1
    fi
  done
}

function save-excurstion {
  dir="${1}"; shift

  pwd
  pushd "${dir}"
  ${@}
  popd
}

function install-ubuntu-packages {
  for package in "${@}"; do
    if ! dpkg -s "${package}" &>/dev/null; then
      sudo apt-get install "${@}"
      break
    fi
  done
}

which-or-die node npm

# try to install ubuntu pre-reqs
if [[ -f /proc/version ]]; then
  if grep Ubuntu /proc/version &>/dev/null; then
    echo "Detected ubuntu, attempting to install pre-reqs:"
    install-ubuntu-packages "libxml2-dev" "build-essential"
  fi
fi

git clone git://github.com/philjackson/apiaxle.git

cd apiaxle

# have npm do its thing
for d in base proxy api; do
  save-excurstion "${d}" npm install
done

for d in proxy api; do
  save-excurstion "${d}" npm link ../base
done

npm install -g coffee-script

echo -e "\n\nHopefully you're done. Have a look at the documentation:" >&2
echo    "  http://apiaxle.com/docs/try-it-now/" >&2
echo    "to see how to proceed." >&2
