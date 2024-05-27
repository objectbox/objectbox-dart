#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

# Optional script to simplify the initial setup: run this script to pub-get all packages and generate code.
# If you don't want all packages, you can also run the commands manually for each package when you actually need it.

# log colors setup
INFO='\033[1;34m'
WARN='\033[1;31m'
NC='\033[0m' # no color

function initialize() {
  local tool=$1
  local dir=$2
  local action=${3:-}

  if [[ ! -x "$(command -v "$tool")" ]]; then
    echo -e "${WARN}Command '$tool' not found. Skipping setup of directory '$dir'${NC}"
    return
  fi
  echo -e "${INFO}Setting up directory '$dir'${NC}"

  (
    cd "$dir" || exit 1
    $tool pub get
    if [[ "$action" == "generate" ]]; then
      if [[ "$(basename "$tool")" == "flutter" ]]; then
        # Flutter ~2.0 fails: The pubspec.lock file has changed since the .dart_tool/package_config.json file was generated, please run "pub get" again.
        # So we do exactly as suggested... Looks like something to do with path dependency_overrides. Try to remove the workaround with the next stable release.
        local generateCmd="$tool pub run build_runner build"
        $generateCmd || ($tool pub get && $generateCmd)
      else
        $tool run build_runner build
      fi
    fi
  )
}

initialize dart objectbox
initialize dart generator
initialize dart objectbox_test generate
initialize dart benchmark generate
initialize dart objectbox/example/dart-native/vectorsearch_cities generate
initialize flutter objectbox/example/flutter/objectbox_demo generate
initialize flutter objectbox/example/flutter/objectbox_demo_relations generate
initialize flutter objectbox/example/flutter/objectbox_demo_sync generate
