#!/usr/bin/env bash
set -euo pipefail

# NOTE: run this script before publishing

# https://github.com/objectbox/objectbox-swift/releases/
obxSwiftVersion="1.5.0-sync-rc5"

dir=$(dirname "$0")

#url="https://github.com/objectbox/objectbox-swift/releases/download/v${obxSwiftVersion}/ObjectBox-framework-${obxSwiftVersion}.zip"
url="https://github.com/objectbox/objectbox-swift-spec-staging/releases/download/v1.x/ObjectBox-xcframework-${obxSwiftVersion}.zip"
zip="${dir}/fw.zip"

curl --location --fail --output "${zip}" "${url}"

frameworkPath=Carthage/Build/ObjectBox.xcframework/ios-arm64/ObjectBox.framework

rm -rf "${dir}/Carthage"
unzip "${zip}" -d "${dir}" \
  "${frameworkPath}/Headers/*" \
  "${frameworkPath}/ObjectBox" \
  "${frameworkPath}/Info.plist"

rm "${zip}"