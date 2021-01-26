#!/usr/bin/env bash
set -euo pipefail

root=$(
  cd "$(dirname "$0")/.."
  pwd -P
)
echo "Package root dir: $root"

if [[ "$#" -gt "1" ]]; then
  echo "usage: $0 [test name]"
  echo "e.g. $0"
  echo "or   $0 query"
  exit 1
fi

testDir="${root}/build/test/valgrind"
rm -rf "${testDir}"
mkdir -pv "${testDir}"
cd "${testDir}" || exit 1


function testWithValgrind() {
  echo "Running $1 with valgrind"

  dart2native "${root}/test/${1}" --output ./test --verbose
  valgrind \
    --leak-check=full \
    --error-exitcode=1 \
    --show-mismatched-frees=no \
    --show-possibly-lost=no \
    --errors-for-leak-kinds=definite \
    ./test

  echo "$1 successful - no errors reported by valgrind"
  echo "--------------------------------------------------------------------------------"
}

if [[ "$#" -gt "0" ]]; then
  testWithValgrind "${1}_test.dart"
else
  for file in "${root}/test/"*_test.dart
  do
    testWithValgrind $(basename $file)
  done
fi

echo "Test passed, cleaning up"
cd "${root}" || exit 1
rm -rf "${testDir}"