# Generator unit tests

Unit tests for the [`objectbox_generator`](..) package. For the generator integration tests, see
[integration-tests](../integration-tests/README.md).

To set up, in the `generator` directory run:

```bash
dart pub get
```

And run the tests:

```bash
dart test --concurrency=1 --reporter expanded
```

Test suites (== test files) must not run in parallel, so always use `--concurrency=1`. Tests using
[`GeneratorTestEnv`](generator_test_env.dart) create and delete files in the `lib` directory, which
breaks when multiple test suites run at the same time. `--reporter expanded` prints the log for
every completed test.

To run a single test suite:

```bash
dart test --reporter expanded test/code_builder_test.dart
```
