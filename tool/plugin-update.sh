#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

# Begins an update of the Flutter plugin packages.
# First, make sure to switch your Flutter SDK to the lowest version the ObjectBox packages support
# (see pubspec.yaml files).
# Then delete the platform-specific subdirectories (e.g. android, ios, ...) and optionally
# other files (e.g. pubspec.yaml).
# Then manually review the changes and commit what's necessary.
# See /dev-doc/packaging.md on details about this setup.

function create() {
  dir=$1
  cd "$root/$dir" || exit 1

  flutter create \
    --template=plugin \
    --org=io.objectbox \
    --platforms=ios,android,linux,macos,windows \
    --project-name=objectbox_$dir \
    .

  # we don't want any changes to these dirs
  git clean -fxd example
  git clean -fxd test
}

create flutter_libs
create sync_flutter_libs
