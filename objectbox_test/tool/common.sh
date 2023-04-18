#!/usr/bin/env bash
# this file is meant to be includes ("sourced") from other scripts
set -euo pipefail

# macOS does not have realpath and readlink does not have -f option, so do this instead:
root=$(
  cd "$(dirname "$0")/.."
  pwd -P
)
echo "Repo root dir: $root"
