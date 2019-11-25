#!/usr/bin/env bash
set -euo pipefail

myDir=$(dirname $0)

for testCase in "${myDir}"/test/*/ ; do
    echo "Testing $testCase"

    # Clean up beforehand by remove all ignored files
    git clean -fXd $testCase

    cd $testCase
    pub get
    pub run test ./before_generation.dart
    pub run build_runner build
    pub run test ./after_generation.dart
done
