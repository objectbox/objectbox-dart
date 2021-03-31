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
# So we do exactly as suggested... Looks like something to do with path dependency_overrides. Try to remove the workaround with the next stable release.
generateCmd="flutter pub run build_runner build --delete-conflicting-outputs"
$generateCmd || (flutter pub get && $generateCmd)

# flutter drive is currently not available in GitHub Actions (TODO start an emulator/simulator?)
if [[ "${GITHUB_ACTIONS:-}" == "" ]]; then
  flutter drive --verbose --target=test_driver/app.dart
fi

flutter build apk
flutter build appbundle
if [[ "$(uname)" == "Darwin" ]]; then
  flutter build ios --no-codesign
fi
