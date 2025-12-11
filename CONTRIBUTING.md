# Contributing

For public issues see the [GitHub issue tracker](https://github.com/objectbox/objectbox-dart/issues).

We welcome smaller contributions, be it by coding, improving docs or just proposing a new feature. 
Look for tasks having a [**"help wanted"**](https://github.com/objectbox/objectbox-dart/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22) tag. 
When picking up an existing issue, please talk to us beforehand by commenting in the issue. 
Don't hesitate to reach out for guidance or to discuss a solution proposal!

## Code contributions

When creating a Pull Request for code changes, please check that you cover the following:

- Include tests for the changes you introduce. See the [test package](objectbox_test) for examples.
- Formatted your changes using `dart format`.
- If the change affects users of this library, update the `## latest` section in the `CHANGELOG.md` 
  by adding a single-line comment what changes.

## Basic technical approach

ObjectBox offers a [C API](https://github.com/objectbox/objectbox-c) which can be called by [Dart FFI](https://dart.dev/server/c-interop).
The C API is also used by the ObjectBox language bindings for [Go](https://github.com/objectbox/objectbox-go), [Swift](https://github.com/objectbox/objectbox-swift), and [Python](https://github.com/objectbox/objectbox-python).
These languages may serve as an inspiration for this Dart implementation.
Internally, ObjectBox uses [FlatBuffers](https://google.github.io/flatbuffers/) to store objects.

## Code organization

This is a multi-package Dart/Flutter repository.
The core runtime library (`objectbox/`) provides the database API via Dart FFI bindings to the ObjectBox C library.
Code generation (`generator/`) uses `build_runner` to produce entity bindings at compile time.
Flutter apps include native libraries via platform-specific plugin packages (`flutter_libs/`, `sync_flutter_libs/`).

- **`objectbox/`** – Core runtime package published as `objectbox` on pub.dev.
  - `lib/objectbox.dart` – Public API exports (Store, Box, Query, annotations, Sync, etc.).
  - `lib/src/native/` – FFI bindings and native implementations (Store, Box, Query, Sync).
  - `lib/src/native/bindings/` – Auto-generated C bindings via `ffigen` and ObjectBox C headers.
  - `lib/src/modelinfo/` – Model metadata classes used by the generator and runtime.
  - `lib/src/relations/` – ToOne/ToMany relation implementations.
  - `lib/src/annotations.dart` – Entity/property annotations (`@Entity`, `@Id`, `@Property`, etc.).
  - `example/` – Example Dart/Flutter apps demonstrating usage.

- **`generator/`** – Code generator package published as `objectbox_generator`.
  - `lib/src/entity_resolver.dart` – Parses annotated entity classes using the Dart analyzer.
  - `lib/src/code_builder.dart` – Orchestrates code generation via `build_runner`.
  - `lib/src/code_chunks.dart` – Generates `objectbox.g.dart` and `objectbox-model.json`.
  - `integration-tests/` – End-to-end generator tests with sample entity definitions.

- **`flutter_libs/`** – Flutter plugin package (`objectbox_flutter_libs`) bundling native ObjectBox libraries for Android, iOS, Linux, macOS, and Windows.

- **`sync_flutter_libs/`** – Flutter plugin package (`objectbox_sync_flutter_libs`) bundling native libraries with ObjectBox Sync support.

- **`objectbox_test/`** – Internal test package (not published).
  Contains comprehensive tests for the runtime: Box, Query, relations, Sync, observers, isolates, etc.
  Uses `dependency_overrides` to test against local `objectbox/` and `generator/`.

- **`benchmark/`** – Performance benchmarks comparing ObjectBox operations.

- **`tool/`** – Shell scripts for development and release workflows:
  - Version management (`set-version.sh`, `set-c-version.sh`).
  - C library updates (`update-c-binding.sh`).
  - Publishing (`publish.sh`, `pub.sh`).

- **`dev-doc/`** – Internal developer documentation: updating the C library, adding property types, packaging, updating examples.

- **`.github/`** – GitHub Actions workflows and issue templates.

- **`.gitlab-ci.yml`** – GitLab CI pipeline configuration.

