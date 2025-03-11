#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

if [[ "$#" -ne "1" ]]; then
  echo "usage: $0 <version>"
  echo "e.g. $0 0.10.0"
  exit 1
fi

version=$1

echo "Setting version: $version"

# Package versions
versionExpr="s/version: .*/version: ${version}/g"
update objectbox/pubspec.yaml "${versionExpr}"
update generator/pubspec.yaml "${versionExpr}"
update flutter_libs/pubspec.yaml "${versionExpr}"
update sync_flutter_libs/pubspec.yaml "${versionExpr}"

# Version constant in generator package
versionDartExpr="s/current = \".*\"/current = \"${version}\"/g"
update generator/lib/src/version.dart "${versionDartExpr}"

# Package dependencies using a version range with caret syntax (like "objectbox: ^1.2.3")
dependencyHigherExpr="s/objectbox: \^.*/objectbox: ^${version}/g"
update objectbox/example/dart-native/vectorsearch_cities/pubspec.yaml "${dependencyHigherExpr}"
update objectbox/example/flutter/event_management_tutorial/event_manager/pubspec.yaml "${dependencyHigherExpr}"
update objectbox/example/flutter/event_management_tutorial/many_to_many/pubspec.yaml "${dependencyHigherExpr}"
update objectbox/example/flutter/objectbox_demo/pubspec.yaml "${dependencyHigherExpr}"
update objectbox/example/flutter/objectbox_demo_sync/pubspec.yaml "${dependencyHigherExpr}"

# Package dependencies using a concrete version (like "objectbox: 1.2.3")
dependencyExactExpr="s/objectbox: [0-9]\+.*/objectbox: ${version}/g"
update objectbox/example/flutter/objectbox_demo_relations/pubspec.yaml "${dependencyExactExpr}"
update generator/pubspec.yaml "${dependencyExactExpr}"
update flutter_libs/pubspec.yaml "${dependencyExactExpr}"
update sync_flutter_libs/pubspec.yaml "${dependencyExactExpr}"

# Changelog latest title
update objectbox/CHANGELOG.md "s/## latest.*/## ${version} ($(date -I))/g"