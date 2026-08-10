#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

if [[ "$#" -ne "1" ]]; then
  echo "usage: $0 <version>"
  echo "e.g. $0 0.10.0"
  exit 1
fi

version=$1

echo "Building examples for released version: $version"

testDir="${root}/build/test/${version}"
rm -rf "${testDir}"
mkdir -pv "${testDir}"
cd "${testDir}" || exit 1

archiveFile="objectbox-${version}.tar.gz"
curl --fail --show-error --location --output "${archiveFile}" \
  "https://pub.dev/api/archives/objectbox-${version}.tar.gz"
tar xzf "${archiveFile}" -C .
rm "${archiveFile}"

make examples

echo "Test passed, cleaning up"
cd "${root}" || exit 1
rm -rf "${testDir}"
