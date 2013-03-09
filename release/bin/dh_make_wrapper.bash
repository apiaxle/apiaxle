#!/usr/bin/env bash

# annoyingly dh_make asks for conformation, and exits with a 0 if it
# fails...
echo "" | dh_make "${@}"
