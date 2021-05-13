#!/usr/bin/env bash
set -eu

# https://github.com/objectbox/objectbox-c/releases
# It's important that the generated dart bindings and the c-api library version match. Dart won't error on C function
# signature mismatch, leading to obscure memory bugs.
# After upgrading to a different C-API version:
#   * update lib/src/bindings/objectbox.h
#   * execute pub run ffigen
#   * have a look at the changed files to see if some call sites need to be updated
cLibVersion=0.14.0
os=$(uname)
cLibArgs="$*"

# if there's no tty this is probably part of a docker build - therefore we install the c-api explicitly
if [[ "$os" != MINGW* ]] && [[ "$os" != CYGWIN* ]] && [[ "$cLibArgs" != *"--install"* ]]; then
  tty -s || cLibArgs="${cLibArgs} --install"
fi


bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-c/main/download.sh) ${cLibArgs} ${cLibVersion}
