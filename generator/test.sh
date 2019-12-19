#!/usr/bin/env bash
set -euo pipefail

myDir=$(dirname "$0")

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
      pub run build_runner build
    fi
    echo "Running ${file}"
    pub run test "${file}"
  fi
}

function runTestCase() {
  testCase=$1
  echo "Testing ${testCase}"

  # Clean up beforehand by removing all ignored files
  git clean -fXd "${testCase}"

  cd "${testCase}"

  pub get
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
