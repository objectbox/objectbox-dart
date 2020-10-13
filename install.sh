#!/usr/bin/env bash
set -eu

# https://github.com/objectbox/objectbox-c/releases
# Warning: ensure C lib signature changes are reflected in lib/src/bindings/signatures.dart
# Dart won't error if they do not match, it may lead to obscure memory bugs.
cLibVersion=0.10.0
os=$(uname)

# if there's no tty this is probably part of a docker build - therefore we install the c-api explicitly
cLibArgs=
if [[ "$os" != MINGW* ]] && [[ "$os" != CYGWIN* ]]; then
  tty -s || cLibArgs="${cLibArgs} --install"
fi

bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-c/main/download.sh) ${cLibArgs} ${cLibVersion}
