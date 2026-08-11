#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

if [[ "$#" -ne "1" ]]; then
  echo "usage: $0 <version>"
  echo "e.g. $0 3.0.0"
  exit 1
fi

version=$1

echo "Setting Android database library dependency versions to: $version"

# Regular expressions match any version string ending with a double quote ("),
# such as -android-db:1.2.3" or android-db:1.2.3-preview1"
versionExpr="s/-android-db:[^\"]*/-android-db:${version}/g"
update flutter_libs/android/build.gradle.kts "${versionExpr}"
update sync_flutter_libs/android/build.gradle.kts "${versionExpr}"

versionExpr="s/objectbox-android-db-admin:[^\"]*/objectbox-android-db-admin:${version}/g"
update objectbox/example/flutter/objectbox_demo_relations/android/app/build.gradle.kts "${versionExpr}"
