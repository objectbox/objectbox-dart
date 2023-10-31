#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

# Begins an update of the Flutter plugin packages.
# You need to manually review the changes and commit what's necessary.
# This will not delete existing files (e.g. if they were removed from the template),
# to do so manually delete all files before.
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
