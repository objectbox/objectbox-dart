# objectbox_test_app

objectbox test application. Helps run integration tests on Android, and on macOS (Mesh Sync via the
Swift Package Manager integration, see the `objectbox_sync_flutter_libs` README).

## Running the tests

Assuming a single running Android emulator:

```bash
flutter test integration_test -d emulator-5554
```

To only run a single test file:

```bash
flutter test integration_test/sync_test.dart -d emulator-5554
```

On macOS (runs the app on the Mac itself; the first mesh test may trigger the Local Network prompt):

```bash
flutter test integration_test -d macos
```

The macOS and iOS folders are Flutter's templates plus the Mesh Sync requirements: deployment targets macOS 12 and
iOS 15 (as required by the ObjectBox Swift Package), the app group required by ObjectBox in sandboxed macOS apps,
the network and Bluetooth sandbox entitlements and the `NSLocalNetworkUsageDescription` and
`NSBluetoothAlwaysUsageDescription` Info.plist entries.
