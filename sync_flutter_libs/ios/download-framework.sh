#!/usr/bin/env bash
set -euo pipefail

# NOTE: run this script before publishing

echo "Sync-enabled objectbox-swift isn't released yet"
exit 1

# https://github.com/objectbox/objectbox-swift/releases/
obxSwiftVersion="1.4.1"

dir=$(dirname "$0")

url="https://github.com/objectbox/objectbox-swift/releases/download/v${obxSwiftVersion}/ObjectBox-framework-${obxSwiftVersion}.zip"
zip="${dir}/fw.zip"

curl --location --fail --output "${zip}" "${url}"

rm -rf "${dir}/Carthage"
unzip "${zip}" -d "${dir}" \
  "Carthage/Build/iOS/ObjectBox.framework/Headers/*" \
  "Carthage/Build/iOS/ObjectBox.framework/ObjectBox" \
  "Carthage/Build/iOS/ObjectBox.framework/Info.plist"

rm "${zip}"