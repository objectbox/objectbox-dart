#!/usr/bin/env bash
set -euo pipefail

# forward all arguments to an available version of `pub`

if [[ `command -v pub` ]]; then
  pub "$@"
elif [[ `command -v pub.bat` ]]; then
  pub.bat "$@"
else
  dart pub "$@"
fi
