#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

# NOTE: This script requires version 3 of yq.
# Download versions for other architectures from https://github.com/mikefarah/yq/releases/tag/3.4.1
msys=false
case "$( uname )" in                #(
  MSYS* | MINGW* )  msys=true    ;; #(
esac
if [ $msys ]; then
  YQCMD="${root}/tool/yq_windows_amd64.exe"
else
  YQCMD="${root}/tool/yq_linux_amd64"
fi
echo "Testing yq version..."
$YQCMD -V
echo "Testing yq version...DONE"

# ======================= BEFORE publishing==================== #

echo "Removing dependency_overrides from all pubspec.yaml files (backup at pubspec.yaml.original)"
find "${root}" -type f -name "pubspec.yaml" \
  -exec echo "Processing {}" \; \
  -exec cp "{}" "{}.original" \; \
  -exec "$YQCMD" delete -i "{}" dependency_overrides \;

# Update links in READMEs (restored by git restore commands below).
"${root}/tool/pubdev-links.sh"

# =========================== PUBLISH ======================== #
function publish() {
  if [[ "$#" -ne "1" ]]; then
    echo "internal error - function usage: publish <package path>"
    exit 1
  fi

  pkg_dir="${root}/${1}"
  pubspec="${pkg_dir}/pubspec.yaml"

  echo -e "You're about to publish directory \e[33m'${1}'\e[39m as package \e[33m$($YQCMD read "${pubspec}" name) v$($YQCMD read "${pubspec}" version)\e[39m"
  echo -e "\e[31mWARNING: The same version can NOT be published twice!\e[39m"
  read -p " Publish to pub.dev [y/N]? " yn
  case $yn in
  [Yy]*)
    cd "${pkg_dir}" || exit 1
    dart pub publish --force
    ;;
  [Nn]*) ;;
  *) echo "Not publishing this package." ;;
  esac
}

publish generator
publish flutter_libs
publish sync_flutter_libs
publish objectbox

#======================== AFTER publishing==================== #

echo "Restoring pubspec.yaml files from backup pubspec.yaml.original"
find "${root}" -type f -name "pubspec.yaml" \
  -exec echo "Restoring {}" \; \
  -exec mv "{}.original" "{}" \;

echo "Restoring objectbox/README.md"
git restore "${root}/objectbox/README.md"
echo "Restoring objectbox/example/README.md"
git restore "${root}/objectbox/example/README.md"