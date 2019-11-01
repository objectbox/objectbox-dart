Contributing
------------------
This project is completely managed on GitHub using its [issue tracker](https://github.com/objectbox/objectbox-dart/issues) and [project boards](https://github.com/objectbox/objectbox-dart/projects).

Anyone can contribute, be it by coding, improving docs or just proposing a new feature. 
Look for tasks having a [**"help wanted"**](https://github.com/objectbox/objectbox-dart/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22) tag. 
When picking up an existing issue, please let us know in the issue comment. 
Don't hesitate to reach out for guidance or to discuss a solution proposal!

### Code contributions
When creating a Pull Request for code changes, please check that you cover the following:
* Include tests for the changes you introduce. See the [test folder](test) for examples.
* Formatted the code using `dartfmt -l 120`. You can configure your IDE to do this automatically, 
  e.g. VS Code needs the project-specific settings `"editor.defaultFormatter": "Dart-Code.dart-code"` and `"dart.lineLength": 120`.

### Project workflow
Issues on the [project board](https://github.com/objectbox/objectbox-dart/projects/3) are referred to as "cards" which move from left to right:

* New cards start in the "To Do" column.
  Within the column, cards are ordered: more important tasks should be above less important ones.  
* Once somebody starts on a task, the according card is moved to "In progress".
  Also, please assign yourself to the issue.
* Once a task is considered complete (e.g. PR is made), put it in the "Review" column.
* Once another person had a look and is happy, the task is finally moved to "Done" and its closed.

### Basic technical approach
ObjectBox offers a [C API](https://github.com/objectbox/objectbox-c) which can be called by [Dart FFI](https://dart.dev/server/c-interop).
The C API is is also used by the ObjectBox language bindings for [Go](https://github.com/objectbox/objectbox-go), [Swift](https://github.com/objectbox/objectbox-swift), and [Python](https://github.com/objectbox/objectbox-python).
These language bindings currently serve as an example for this Dart implementation.
Internally, ObjectBox uses [FlatBuffers](https://google.github.io/flatbuffers/) to store objects.