#!/usr/bin/env bash
# this file is meant to be includes ("sourced") from other scripts
set -euo pipefail

# macOS does not have realpath and readlink does not have -f option, so do this instead:
root=$(
  cd "$(dirname "$0")/.."
  pwd -P
)
echo "Repo root dir: $root"

# align GNU vs BSD `sed` version handling -i argument
if [[ "$OSTYPE" == "darwin"* ]]; then
  sed="sed -i ''"
else
  sed="sed -i"
fi

function update() {
  if [[ "$#" -ne "2" ]]; then
    echo "internal error - function usage: update <file> <sed expression>"
    exit 1
  fi

  file=${1}
  expr=${2}

  echo "Updating ${file} - \"${expr}\""
  $sed "${expr}" "$root/$file"
}
