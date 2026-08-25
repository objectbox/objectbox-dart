# ObjectBox Dart/Flutter Guidelines

ObjectBox is a high-performance NoSQL database for Dart and Flutter with on-device vector search support.
This ObjectBox Dart SDK uses FFI bindings to a native C library.

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
./install.sh           # Standard library
./install.sh --sync    # Sync-enabled library
```

## Code Style & Formatting

- **Always run `dart format` on changed files before committing**
- CI checks formatting with `dart format --set-exit-if-changed`
- Use `dart analyze` to check for issues

## Testing

Tests are in `objectbox_test/`. Run with:
```bash
cd objectbox_test
dart pub get
dart run build_runner build
dart test
```

Generator integration tests:
```bash
./generator/test.sh
```

Flutter Android integration tests are in `objectbox_test_app/`.
Run them on an already-started Android emulator, for example, if `flutter devices` lists an emulator as `emulator-5554`:

```bash
cd objectbox_test_app
flutter test integration_test/sync_test.dart -d emulator-5554
```

## CI Pipeline

This project is set up to run a pipeline in GitLab CI and two workflows on GitHub CI.

GitLab CI (see [.gitlab-ci.yml](.gitlab-ci.yml)) runs checks and tests for packages that use only
the Dart SDK. Also, tests are only run on Linux.

GitHub CI (see [test](/.github/workflows/test.yml) and [code analysis](/.github/workflows/code-analysis.yml)
workflows) also runs checks and tests that require a Flutter SDK. Tests are run on all supported
platforms (macOS, Linux, Windows). Also, the main examples are verified to build for all supported
platforms (including Android and iOS), indirectly verifying the generator works on all platforms.

In general, CI runs code analysis and format checks, tests the generator, runs unit tests and 
computes test code coverage.

For notes about updating the tested Dart and Flutter SDK versions, see the [related dev doc](/dev-doc/updating-dart-flutter-and-dependencies.md).
For the actually tested versions, see the CI config files linked above.

## Key Technical Details

- **FFI bindings**: ObjectBox uses Dart FFI to call the [ObjectBox C API](https://github.com/objectbox/objectbox-c)
- **FlatBuffers**: Objects are serialized using FlatBuffers internally
- **Code generation**: `build_runner` generates entity bindings at compile time
- **Sync**: Optional data synchronization feature (requires sync-enabled native library)

## Making Changes

1. Include tests for changes (see `objectbox_test/` for examples)
2. Run `dart format` on modified files
3. Update `CHANGELOG.md` under the `## latest` section if the change affects users
4. Run `dart analyze` to check for issues

## Package Versioning

All packages share the same version. Use:
```bash
./tool/set-version.sh <version>
```

## Updating C Library Bindings

See `dev-doc/updating-c-library.md`. Key steps:
1. Update headers in `objectbox/lib/src/native/bindings/`
2. Run `dart run ffigen` in `objectbox/`
3. Update version in `objectbox/lib/src/native/bindings/bindings.dart`
