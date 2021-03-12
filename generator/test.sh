#!/usr/bin/env bash
set -euo pipefail

# TODO enable sound null safety after depependencies are out:
# Because build_runner >=0.9.1+1 depends on io ^0.3.0 and build_runner <=0.9.1 requires SDK version >=1.9.1 <2.0.0-∞, every version of build_runner requires io ^0.3.0.
# So, because objectbox_generator_test depends on both build_runner any and io ^1.0.0, version solving failed.

myDir=$(dirname "$0")

function runTestFile() {
  file="${1}.dart"
  if [ -f "${file}" ]; then
    # execute "N-pre.dart" file if it exists
    if [[ "${1}" != "0" && -f "${1}-pre.dart" ]]; then
      echo "Executing ${1}-pre.dart"
      dart --no-sound-null-safety "${1}-pre.dart"
    fi

    # build before each step, except for "0.dart"
    if [ "${1}" != "0" ]; then
      echo "Running build_runner before ${file}"
      dart pub run build_runner build --verbose
    fi
    echo "Running ${file}"
    dart --no-sound-null-safety test "${file}"
  fi
}

function runTestCase() {
  testCase=$1
  echo "Testing ${testCase}"

  # Clean up beforehand by removing all ignored files
  git clean -fXd "${testCase}"

  cd "${testCase}"

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
