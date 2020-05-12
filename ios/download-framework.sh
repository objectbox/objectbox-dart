#!/usr/bin/env bash
set -euo pipefail

# NOTE: run this script before publishing

# https://github.com/objectbox/objectbox-swift/releases/
obxSwiftVersion="1.3.0"

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