#!/usr/bin/env bash
set -euo pipefail

# https://pub.dev/packages/test#collecting-code-coverage
# Must run test in package directory for which to generate coverage.
# Run only one test suite (== test file) at a time to prevent native errors.
dart test ../objectbox_test --coverage-path=./coverage/lcov.info --concurrency=1
# Exclude some files that can't be tested.
# The pattern must be specified to match the absolute path of each source file.
lcov --remove coverage/lcov.info '*/lib/src/native/admin.dart' '*/lib/src/native/bindings/objectbox_c.dart' '*/lib/src/native/bindings/bindings.dart' '*/lib/src/modelinfo/*' -o coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html || true
