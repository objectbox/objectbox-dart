# ObjectBox Tests

Contains unit tests for the [`objectbox`](../objectbox) package to avoid a cyclic dependency on
[`objectbox_generator`](../generator).

To run set up the package:

```bash
dart pub get
dart run build_runner build
```

And run the tests:

```bash
dart test
```

Or for better log output (e.g. to attribute native logs to a test):

```bash
# Run only one test suite (== test file) at a time.
# Print log for every completed test.
dart test --concurrency=1 --reporter expanded
```

To run tests using an in-memory database:

```bash
export OBX_IN_MEMORY=true
dart test
```
