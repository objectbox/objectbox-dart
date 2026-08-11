#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne "1" ]]; then
  echo "Usage: $0 <app-dir>"
  echo ""
  echo "For example run:"
  echo "    $0 example/flutter/objectbox_demo_relations"
  exit 1
fi

. "$(dirname "$0")"/common.sh

echo ""
echo "ℹ️ Building the example in $1"
echo ""

set -x # Print commands to terminal

cd "${root}/$1"

flutter clean

# Get dependencies
flutter pub get

# Run ObjectBox code generator
dart run build_runner build

# Build for current platform
# Only test App Bundle build, it's the preferred format (and required for new
# apps on Google Play).
# On GitHub Actions, only build Android on Linux to reduce build time.
# flutter build apk
if [[ "${GITHUB_ACTIONS:-}" == "" || "$(uname)" == "Linux" ]]; then
  flutter build appbundle
fi

if [[ "$(uname)" == "Darwin" ]]; then
  flutter build ios --no-codesign
  flutter build macos
elif [[ "$(uname)" == "Linux" ]]; then
  flutter build linux
else
  flutter build windows
fi
