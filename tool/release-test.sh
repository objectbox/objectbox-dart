#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

if [[ "$#" -ne "1" ]]; then
  echo "usage: $0 <version>"
  echo "e.g. $0 0.10.0"
  exit 1
fi

version=$1

echo "Executing an integration test on a released version: $version"

testDir="${root}/build/test/${version}"
rm -rf "${testDir}"
mkdir -pv "${testDir}"
cd "${testDir}" || exit 1

curl -L "https://storage.googleapis.com/pub-packages/packages/objectbox-${version}.tar.gz" | tar xz -C .

make integration-test

echo "Test passed, cleaning up"
cd "${root}" || exit 1
rm -rf "${testDir}"