#!/usr/bin/env bash
set -euo pipefail

# https://pub.dev/packages/test#collecting-code-coverage
# Note: Run test in package directory for which to generate coverage,
# output is in ./objectbox_test despite specifying ./coverage.
# Run only one test suite (== test file) at a time to prevent native errors.
dart test ../objectbox_test --coverage=./coverage --concurrency=1
dart pub global run coverage:format_coverage --packages=.dart_tool/package_config.json --report-on=lib --lcov -o ./coverage/lcov.info -i ./objectbox_test
# The pattern must be specified to match the absolute path of each source file.
lcov --remove coverage/lcov.info '*/lib/src/native/admin.dart' '*/lib/src/native/sync.dart' '*/lib/src/native/bindings/objectbox_c.dart' '*/lib/src/native/bindings/bindings.dart' '*/lib/src/modelinfo/*' -o coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html || true
