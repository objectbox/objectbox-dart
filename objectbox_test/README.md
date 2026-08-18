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

To run tests using a Sync server locally (note that GitLab CI uses a different token option):

```bash
# Set server URL and GitLab private token
export CI_SERVER_URL=REPLACE_ME
export PRIVATE_TOKEN=REPLACE_ME

# Download the server binary and make it discoverable by sync_test.dart
mkdir sync-server && cd sync-server
../../tool/download-server.sh --gitlab-base-url $CI_SERVER_URL --branch sync --private-token $PRIVATE_TOKEN
export PATH="$PATH:$PWD"

cd ..
dart test test/sync_test.dart
```
