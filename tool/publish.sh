. "$(dirname "$0")"/common.sh

# NOTE: This script requires version 3 of yq.
# E.g. download from https://github.com/mikefarah/yq/releases/tag/3.4.1
# and temporarily add to PATH for this script:
# export PATH=$PATH:"/path/to/yq/"

# ======================= BEFORE publishing==================== #

echo "Removing dependency_overrides from all pubspec.yaml files (backup at pubspec.yaml.original)"
find "${root}" -type f -name "pubspec.yaml" \
  -exec echo "Processing {}" \; \
  -exec cp "{}" "{}.original" \; \
  -exec yq delete -i "{}" dependency_overrides \;

# update links in the readme (see `git restore "${root}/objectbox/README.md"` below)
"${root}/tool/pubdev-links.sh"

# =========================== PUBLISH ======================== #
function publish() {
  if [[ "$#" -ne "1" ]]; then
    echo "internal error - function usage: publish <package path>"
    exit 1
  fi

  pkg_dir="${root}/${1}"
  pubspec="${pkg_dir}/pubspec.yaml"

  echo -e "You're about to publish directory \e[33m'${1}'\e[39m as package \e[33m$(yq read "${pubspec}" name) v$(yq read "${pubspec}" version)\e[39m"
  echo -e "\e[31mWARNING: The same version can NOT be published twice!\e[39m"
  read -p " Are you sure you want to publish to pub.dev? " yn
  case $yn in
  [Yy]*)
    cd "${pkg_dir}" || exit 1
    dart pub publish --force
    ;;
  [Nn]*) ;;
  *) echo "Please answer yes or no." ;;
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