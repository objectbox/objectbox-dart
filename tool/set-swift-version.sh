#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

if [[ "$#" -ne "1" ]]; then
  echo "usage: $0 <version>"
  echo "e.g. $0 3.0.0"
  exit 1
fi

version=$1

echo "Setting ObjectBox Swift version: $version"

# Regular expressions match any version string ending with a single quote ('),
# such as 1.2.3' or 1.2.3-beta.1'
versionExpr="s/dependency 'ObjectBox', '[^\']*'/dependency 'ObjectBox', '${version}'/g"
update flutter_libs/ios/objectbox_flutter_libs.podspec "${versionExpr}"
update flutter_libs/macos/objectbox_flutter_libs.podspec "${versionExpr}"

versionExpr="s/dependency 'ObjectBox', '[^\']*'/dependency 'ObjectBox', '${version}-sync'/g"
update sync_flutter_libs/ios/objectbox_sync_flutter_libs.podspec "${versionExpr}"
update sync_flutter_libs/macos/objectbox_sync_flutter_libs.podspec "${versionExpr}"
