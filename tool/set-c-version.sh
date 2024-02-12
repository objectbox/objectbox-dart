#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

# Changes the C library version used in
# - the install script (for Dart Native and unit tests) and
# - both Flutter plugins (for Flutter on Linux, Windows).

if [[ "$#" -ne "1" ]]; then
  echo "usage: $0 <version>"
  echo "e.g. $0 0.20.0"
  exit 1
fi

version=$1

echo "Setting cLibVersion and OBJECTBOX_VERSION version: $version"

versionExpr="s/cLibVersion=[0-9]\+\.[0-9]\+\.[0-9]\+/cLibVersion=${version}/g"
update install.sh "${versionExpr}"

versionExpr="s/OBJECTBOX_VERSION [0-9]\+\.[0-9]\+\.[0-9]\+/OBJECTBOX_VERSION ${version}/g"
update flutter_libs/linux/CMakeLists.txt "${versionExpr}"
update flutter_libs/windows/CMakeLists.txt "${versionExpr}"
update sync_flutter_libs/linux/CMakeLists.txt "${versionExpr}"
update sync_flutter_libs/windows/CMakeLists.txt "${versionExpr}"
