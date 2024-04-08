#!/usr/bin/env bash
set -euo pipefail

. "$(dirname "$0")"/common.sh

if [[ "$#" -ne "1" ]]; then
  echo "usage: $0 <app-dir>"
  echo "e.g. $0 example/objectbox_demo"
  exit 1
fi

set -x

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
