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
# - set --fail to fail on 4xx responses instead of returning a body
# - set --silent to avoid a progress bar
# - set --show-error to still show error messages
# - don't use --location to follow redirects to potentially unsafe location,
#   update the link instead
# - set --retry to avoid having to re-run the script for an intermediate network
#   issue
curl --fail --silent --show-error --retry 3 \
  --output "$downloadScript" \
  https://raw.githubusercontent.com/objectbox/objectbox-c/main/download.sh

bash "$downloadScript" ${cLibArgs} ${cLibVersion}
