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
echo "ℹ️ Testing the example in $1"
echo ""

set -x # Print commands to terminal

cd "${root}/$1"
flutter clean
flutter pub get

# Flutter ~2.0 fails: The pubspec.lock file has changed since the .dart_tool/package_config.json file was generated, please run "pub get" again.
generateCmd="dart run build_runner build --delete-conflicting-outputs"
$generateCmd || (flutter pub get && $generateCmd)

# flutter drive is currently not available in GitHub Actions (TODO start an emulator/simulator?)
if [[ "${GITHUB_ACTIONS:-}" == "" ]]; then
  flutter drive --verbose --target=test_driver/app.dart
fi

# Only test App Bundle build, its the preferred format (and required for new apps on Google Play).
# On GitHub Actions, only build Android on Linux to reduce build time.
# flutter build apk
if [[ "${GITHUB_ACTIONS:-}" == "" || "$(uname)" == "Linux" ]]; then
  flutter build appbundle
fi

if [[ "$(uname)" == "Darwin" ]]; then
  flutter build ios --no-codesign
  flutter config --enable-macos-desktop
  flutter build macos
elif [[ "$(uname)" == "Linux" ]]; then
  flutter config --enable-linux-desktop
  flutter build linux
else
  flutter config --enable-windows-desktop
  flutter build windows
fi
