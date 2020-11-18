#!/usr/bin/env bash
# pre-release script to set version & dependencies in all packages
set -euo pipefail

# macOS does not have realpath and readlink does not have -f option, so do this instead:
root=$(
  cd "$(dirname "$0")/.."
  pwd -P
)
echo "Repo root dir: $root"

if [[ "$#" -ne "1" ]]; then
  echo "usage: $0 <version>"
  echo "e.g. $0 0.10.0"
  exit 1
fi

version=$1

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

echo "Setting version: $version"

versionExpr="s/version: .*/version: ${version}/g"
update pubspec.yaml "${versionExpr}"
update generator/pubspec.yaml "${versionExpr}"
update flutter_libs/pubspec.yaml "${versionExpr}"
update sync_flutter_libs/pubspec.yaml "${versionExpr}"

dependencyHigherExpr="s/objectbox: \^.*/objectbox: ^${version}/g"
update README.md "${dependencyHigherExpr}"
update example/flutter/objectbox_demo/pubspec.yaml "${dependencyHigherExpr}"
update example/flutter/objectbox_demo_desktop/pubspec.yaml "${dependencyHigherExpr}"
update example/flutter/objectbox_demo_sync/pubspec.yaml "${dependencyHigherExpr}"

dependencyExactExpr="s/objectbox: [0-9]\+.*/objectbox: ${version}/g"
update generator/pubspec.yaml "${dependencyExactExpr}"
update flutter_libs/pubspec.yaml "${dependencyExactExpr}"
update sync_flutter_libs/pubspec.yaml "${dependencyExactExpr}"

update CHANGELOG.md "s/## latest.*/## ${version} ($(date -I))/g"