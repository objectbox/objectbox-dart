#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

if [[ "$#" -ne "1" ]]; then
  echo "usage: $0 <version>"
  echo "e.g. $0 3.0.0"
  exit 1
fi

version=$1

echo "Setting objectbox-android, objectbox-sync-android and objectbox-android-objectbrowser version: $version"

versionExpr="s/-android:[0-9]\+\.[0-9]\+\.[0-9]\+/-android:${version}/g"
update flutter_libs/android/build.gradle "${versionExpr}"
update sync_flutter_libs/android/build.gradle "${versionExpr}"

versionExpr="s/objectbox-android-objectbrowser:[0-9]\+\.[0-9]\+\.[0-9]\+/objectbox-android-objectbrowser:${version}/g"
update objectbox/example/flutter/objectbox_demo_relations/android/app/build.gradle "${versionExpr}"
