#!/usr/bin/env bash
set -euo pipefail

# Expects to be run from a sibling directory of the objectbox package and that
# `dart test` with `--coverage=coverage` was run before in the working directory.
# https://pub.dev/packages/test#collecting-code-coverage

# Create report for ../objectbox/lib in coverage/lcov.info
# For options, run dart pub global run coverage:format_coverage --help
dart pub global activate coverage
dart pub global run coverage:format_coverage \
  --lcov \
  --in=coverage \
  --out=coverage/lcov.info \
  --report-on=../objectbox/lib
# Exclude some files that can't be tested.
# The pattern must be specified to match the absolute path of each source file.
lcov --remove coverage/lcov.info '*/lib/src/native/admin.dart' '*/lib/src/native/bindings/objectbox_c.dart' '*/lib/src/native/bindings/bindings.dart' '*/lib/src/modelinfo/*' -o coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html || true
