# ObjectBox Dart/Flutter Guidelines

ObjectBox is a high-performance NoSQL database for Dart and Flutter with on-device vector search
support. This ObjectBox Dart SDK uses FFI bindings to a native C library.

## Repository Structure

This is a **multi-package monorepo**:

- **`objectbox/`** – Core runtime package (`objectbox` on pub.dev)
  - `lib/src/native/` – FFI bindings and native implementations (Store, Box, Query, Sync)
  - `lib/src/native/bindings/` – Auto-generated C bindings via `ffigen`
  - `lib/src/modelinfo/` – Model metadata for generator and runtime
  - `lib/src/relations/` – ToOne/ToMany relation implementations
  - `lib/src/annotations.dart` – Entity annotations (`@Entity`, `@Id`, `@Property`, etc.)

- **`generator/`** – Code generator package (`objectbox_generator` on pub.dev)
  - Uses `build_runner` to generate `objectbox.g.dart` from annotated entities
  - `lib/src/entity_resolver.dart` – Parses entity classes
  - `lib/src/code_chunks.dart` – Generates binding code

- **`objectbox_test/`** – Internal test package (not published)
  - Comprehensive tests for Box, Query, relations, Sync, observers, isolates

- **`flutter_libs/`** – Flutter plugin bundling native libraries for all platforms

- **`sync_flutter_libs/`** – Flutter plugin with ObjectBox Sync support

- **`benchmark/`** – Performance benchmarks

- **`tool/`** – Shell scripts for versioning, publishing, and C library updates

- **`dev-doc/`** – Internal developer documentation

## Development Setup

```bash
./tool/init.sh
```

This initializes the workspace, downloads native libraries, and generates code.

To download the native library for a specific package:

```bash
./install.sh --sync    # Sync-enabled library, recommended
./install.sh           # Standard library
```

## Code Style & Formatting

- **Always run `dart format` on changed files before committing**
- CI checks formatting with `dart format --set-exit-if-changed`
- Use `dart analyze` to check for issues
- In Markdown files, wrap lines so they don't exceed 100 characters. Exception: in `CHANGELOG.md`,
  don't wrap lines, so entries can be copied as-is to GitHub release notes.

## Testing

Unit tests for the `objectbox` package are in `objectbox_test/`. See its
[README](objectbox_test/README.md) for setup and options (in-memory database, Sync server, better
log output). In short:

```bash
cd objectbox_test
dart pub get
dart run build_runner build
dart test --concurrency=1 --reporter expanded
```

Generator unit tests are in `generator/test/`. Test suites must not run in parallel, see its
[README](generator/test/README.md). In short:

```bash
cd generator
dart pub get
dart test --concurrency=1 --reporter expanded
```

Generator integration tests are in `generator/integration-tests/`. They require the native library
to be installed globally (`./install.sh --install`) or in the tested directory. See their
[README](generator/integration-tests/README.md) for how test cases are structured. In short:

```bash
./generator/test.sh             # Run all tests
./generator/test.sh basics      # Run a specific test (directory name)
```

Flutter Android integration tests are in `objectbox_test_app/`. They run on an already-started
Android emulator. See its [README](objectbox_test_app/README.md).

## CI Pipeline

This project runs a pipeline on GitLab CI and workflows on GitHub CI. In general, CI checks
formatting, runs code analysis, runs generator and unit tests with the latest and lowest supported
SDK, and computes test code coverage.

GitLab CI (see [.gitlab-ci.yml](.gitlab-ci.yml)) checks and tests only packages that don't require
a Flutter SDK, and only on Linux. Unlike GitHub CI, it runs the Sync tests against a Sync server. It
also builds and runs the Dart Native vector search example.

GitHub CI (see the [test](/.github/workflows/test.yml) and
[code analysis](/.github/workflows/code-analysis.yml) workflows) additionally:

- checks formatting and analyzes all packages, including Flutter packages
- runs unit tests on Linux, macOS and Windows
- builds the main Flutter examples for all supported platforms (including Android and iOS),
  indirectly verifying the generator works on all platforms
- builds the Flutter test app with the latest and lowest supported Flutter SDK
- checks the `./tool/init.sh` script works
- checks the pub.dev score of the `objectbox` package
- requires a minimum test code coverage

For notes about updating the tested Dart and Flutter SDK versions, see the
[related dev doc](/dev-doc/updating-dart-flutter-and-dependencies.md).
For the actually tested versions, see the CI config files linked above.

## Key Technical Details

- **FFI bindings**: ObjectBox uses Dart FFI to call the
  [ObjectBox C API](https://github.com/objectbox/objectbox-c)
- **FlatBuffers**: Objects are serialized using FlatBuffers internally
- **Code generation**: `build_runner` generates entity bindings at compile time
- **Sync**: Optional data synchronization feature (requires sync-enabled native library)

## Making Changes

1. Include tests for changes (see `objectbox_test/` for examples)
2. Run `dart format` on modified files
3. Update `CHANGELOG.md` under the `## latest` section if the change affects users
4. Run `dart analyze` to check for issues

## Commit Messages

Do not add AI/agent attribution to commit messages or PR descriptions: no `Co-Authored-By`
trailers for AI tools (e.g. `Co-Authored-By: Claude ...`) and no "Generated with ..." lines.
Describe the change itself; authorship is tracked by the regular git author.

## Package Versioning

All packages share the same version. Use:
```bash
./tool/set-version.sh <version>
```

## Updating C Library Bindings

See the [related dev doc](dev-doc/updating-c-library.md). Key steps:

1. Run `./tool/update-c-binding.sh` to download the header files and generate bindings with ffigen
   (configuration is in `objectbox/tool/ffigen.dart`). If the header files are not available on
   GitHub yet, manually copy them to `objectbox/lib/src/native/bindings/` and run the script with
   `--skip-download`.
2. Update version in `objectbox/lib/src/native/bindings/bindings.dart`
