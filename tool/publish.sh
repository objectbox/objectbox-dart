. "$(dirname "$0")"/common.sh

# ======================= BEFORE publishing==================== #

echo "Downloading iOS dependencies for package flutter libs"
"${root}"/flutter_libs/ios/download-framework.sh
# TODO enable once objectbox-swift with Sync is released
#"${root}"/sync_flutter_libs/ios/download-framework.sh

echo "Commenting-out Carthage in .gitignore in flutter libs"
update flutter_libs/ios/.gitignore "s/^Carthage/#Carthage/g"
update sync_flutter_libs/ios/.gitignore "s/^Carthage/#Carthage/g"

echo "Removing dependency_overrides from all pubspec.yaml files (backup at pubspec.yaml.original)"
find "${root}" -type f -name "pubspec.yaml" \
  -exec echo "Processing {}" \; \
  -exec cp "{}" "{}.original" \; \
  -exec yq delete -i "{}" dependency_overrides \;

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
    pub publish --force
    ;;
  [Nn]*) ;;
  *) echo "Please answer yes or no." ;;
  esac
}

publish objectbox
publish generator
publish flutter_libs
publish sync_flutter_libs
#======================== AFTER publishing==================== #

echo "Uncommenting Carthage in .gitignore in flutter libs"
update flutter_libs/ios/.gitignore "s/^#Carthage/Carthage/g"
update sync_flutter_libs/ios/.gitignore "s/^#Carthage/Carthage/g"

echo "Restoring pubspec.yaml files from backup pubspec.yaml.original"
find "${root}" -type f -name "pubspec.yaml" \
  -exec echo "Restoring {}" \; \
  -exec mv "{}.original" "{}" \;
