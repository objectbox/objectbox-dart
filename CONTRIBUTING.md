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
