#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

# NOTE: This script requires version 3 of yq.
# Download versions for other architectures from https://github.com/mikefarah/yq/releases/tag/3.4.1
msys=false
case "$( uname )" in                #(
  MSYS* | MINGW* )  msys=true    ;; #(
esac
if [ "$msys" = true ]; then
  YQCMD="${root}/tool/yq_windows_amd64.exe"
else
  YQCMD="${root}/tool/yq_linux_amd64"
fi
echo "Testing yq version..."
$YQCMD -V
echo "Testing yq version...DONE"

# ======================= BEFORE publishing==================== #

# Disabled to publish with Dart SDK 2.19, see objectbox/objectbox-dart#55.
#echo "Removing dependency_overrides from all pubspec.yaml files (backup at pubspec.yaml.original)"
#find "${root}" -type f -name "pubspec.yaml" \
#  -exec echo "Processing {}" \; \
#  -exec cp "{}" "{}.original" \; \
#  -exec "$YQCMD" delete -i "{}" dependency_overrides \;

# Update links in READMEs (restored by git restore commands below).
"${root}/tool/pubdev-links.sh"

# Verify MixPanel project token file exists. Obtain token from MixPanel project settings.
echo "analysis: checking if generator/lib/assets/analysis-token.txt exists..."
analysisTokenFile="${root}/generator/lib/assets/analysis-token.txt"
if [ -f $analysisTokenFile ]; then
  echo "analysis: analysis-token.txt found, proceeding with release."
else
  read -p "WARNING analysis: analysis-token.txt not found, release with analysis *disabled*? [y/N]: " answer
  case $answer in
    [Yy]*)
      echo "WARNING Releasing with analysis *disabled*."
      ;;
    *)
      echo "See analysis_test.dart on how to create a analysis-token.txt file."
      exit 1
      ;;
  esac
fi

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

# Publish packages that others depend on first to pass publish checks.
publish objectbox
publish generator
publish flutter_libs
publish sync_flutter_libs

#======================== AFTER publishing==================== #

# Disabled to publish with Dart SDK 2.19, see objectbox/objectbox-dart#55.
#echo "Restoring pubspec.yaml files from backup pubspec.yaml.original"
#find "${root}" -type f -name "pubspec.yaml" \
#  -exec echo "Restoring {}" \; \
#  -exec mv "{}.original" "{}" \;

echo "Restoring objectbox/README.md"
git restore "${root}/objectbox/README.md"
echo "Restoring objectbox/example/README.md"
git restore "${root}/objectbox/example/README.md"