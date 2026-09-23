#!/usr/bin/env bash
set -euo pipefail

# Runs all tests in the integration-test folder with
# ./test.sh
# or a specific one with
# ./test.sh <folder> e.g. ./test.sh basics

# Absolute path, runTestCase changes the working directory
myDir=$(cd "$(dirname "$0")" && pwd)

# Download the database library once into a temporary directory,
# runTestCase copies it into the lib directory of each test case.
# Use --quiet to skip interactive questions of the download script.
libDownloadDir=$(mktemp -d)
trap 'rm -rf "$libDownloadDir"' EXIT
(cd "${libDownloadDir}" && "${myDir}/../install.sh" --quiet)

function runTestFile() {
  file="${1}.dart"
  if [ -f "${file}" ]; then
    # execute "N-pre.dart" file if it exists
    if [[ "${1}" != "0" && -f "${1}-pre.dart" ]]; then
      echo "Executing ${1}-pre.dart"
      dart "${1}-pre.dart"
    fi

    # build before each step, except for "0.dart"
    if [ "${1}" != "0" ]; then
      echo "Running build_runner before ${file}"
      dart run build_runner build --verbose
    fi
    echo "Running ${file}"
    dart test "${file}"
  fi
}

function runTestCase() {
  testCase=$1
  echo "Testing ${testCase}"

  # Clean up beforehand by removing all ignored files
  git clean -fXd "${testCase}"

  cd "${testCase}"

  # Copy the database library (the test case loads it from its lib directory)
  mkdir -p lib
  cp "${libDownloadDir}"/lib/* lib/

  dart pub get
  for i in {0..9}; do
    runTestFile $i
  done

  cd -
}

if [ $# -eq 0 ]; then
  for testCase in "${myDir}"/integration-tests/*/; do
    runTestCase "${testCase}"
  done
else
  runTestCase "${myDir}/integration-tests/$1"
fi
