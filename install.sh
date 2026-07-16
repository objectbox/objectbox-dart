#!/usr/bin/env bash
set -eu

# https://github.com/objectbox/objectbox-c/releases
# It's important that the generated dart bindings and the c-api library version match. Dart won't error on C function
# signature mismatch, leading to obscure memory bugs.
# For how to upgrade the version see dev-doc/updating-c-library.md
cLibVersion=6.0.0-beta
os=$(uname)
cLibArgs="$*"

# Download to a file first: with `bash <(curl -s ...)` a failed download (e.g.
# network error) resulted in an empty script and this exiting with 0 as if the
# library was installed.
downloadScript=$(mktemp)
trap 'rm -f "$downloadScript"' EXIT
curl -fsSL --retry 3 -o "$downloadScript" https://raw.githubusercontent.com/objectbox/objectbox-c/main/download.sh

bash "$downloadScript" ${cLibArgs} ${cLibVersion}
