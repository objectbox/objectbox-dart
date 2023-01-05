#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

if [[ "$#" -ne "1" ]]; then
  echo "usage: $0 <version>"
  echo "e.g. $0 3.0.0"
  exit 1
fi

version=$1

echo "Setting ObjectBox Swift version: $version"

versionExpr="s/dependency 'ObjectBox', '[0-9]\+\.[0-9]\+\.[0-9]'/dependency 'ObjectBox', '${version}'/g"
update flutter_libs/ios/objectbox_flutter_libs.podspec "${versionExpr}"
update flutter_libs/macos/objectbox_flutter_libs.podspec "${versionExpr}"

versionExpr="s/dependency 'ObjectBox', '[0-9]\+\.[0-9]\+\.[0-9]-sync'/dependency 'ObjectBox', '${version}-sync'/g"
update sync_flutter_libs/ios/objectbox_sync_flutter_libs.podspec "${versionExpr}"
update sync_flutter_libs/macos/objectbox_sync_flutter_libs.podspec "${versionExpr}"
