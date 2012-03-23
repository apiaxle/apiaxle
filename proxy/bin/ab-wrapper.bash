#!/usr/bin/env bash

set -e

tmp=$(mktemp)

ab -n 15000 -v3 -c "${1}" "${2}" > "${tmp}"

# count the reponses
cat "${tmp}" | \
  perl -MData::Dumper -nle 'END{ print Dumper(\%A) } /^HTTP\/1.1 (\d{3})/ && $A{$1}++'

echo "Data in ${tmp}"

# overall time taken
tail -n 30 "${tmp}"
