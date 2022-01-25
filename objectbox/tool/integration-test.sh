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

flutter pub run build_runner build --delete-conflicting-outputs

# flutter drive is currently not available in GitHub Actions (TODO start an emulator/simulator?)
if [[ "${GITHUB_ACTIONS:-}" == "" ]]; then
  flutter drive --verbose --target=test_driver/app.dart
fi

flutter build apk
flutter build appbundle

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
