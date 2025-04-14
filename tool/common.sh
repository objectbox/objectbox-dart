#!/usr/bin/env bash
# this file is meant to be includes ("sourced") from other scripts
set -euo pipefail

# macOS does not have realpath and readlink does not have -f option, so do this instead:
root=$(
  cd "$(dirname "$0")/.."
  pwd -P
)
echo "Repo root dir: $root"

# macOS includes the BSD version of sed, which uses a different syntax than the
# GNU version, which these scripts expect. So require users of this script to
# install gsed.
if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command -v gsed &>/dev/null; then
    echo "Error: gsed is required but not installed. Install it, for example using 'brew install gsed'."
    exit 1
  fi
  sed="gsed"
else
  sed="sed"
fi

function update() {
  if [[ "$#" -ne "2" ]]; then
    echo "internal error - function usage: update <file> <sed expression>"
    exit 1
  fi

  file=${1}
  expr=${2}

  echo "Updating ${file} - \"${expr}\""
  $sed -i "${expr}" "$root/$file"
}
