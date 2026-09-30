# ObjectBox database (with [Sync](https://objectbox.io/sync)) libraries for Flutter

[![pub package](https://img.shields.io/pub/v/objectbox_sync_flutter_libs.svg)](https://pub.dev/packages/objectbox_sync_flutter_libs)

This package provides the native ObjectBox database library, with the [Sync](https://objectbox.io/sync) 
client included, as a Flutter plugin for supported platforms.
Check the [Sync docs](https://sync.objectbox.io/) for more details.
You should add this package as a dependency when using [ObjectBox](https://pub.dev/packages/objectbox) with Flutter.

See package [objectbox](https://pub.dev/packages/objectbox) for more details and
information how to use it.

## Mesh Sync

See the [Mesh Sync documentation](https://sync.objectbox.io/mesh-sync) for 
details.

Configure the mesh Sync like this:

```dart
import 'package:objectbox/objectbox.dart';
import 'package:objectbox_sync_flutter_libs/objectbox_sync_flutter_libs.dart'
    show createMeshConfig;

final mesh = await createMeshConfig('mesh-id');
final client = SyncClient(store, urls, credentials, mesh: mesh);
```

Mesh Sync is available for Flutter Android, iOS and macOS apps;
see the platform notes below.

### Android

On Android, apps using Mesh Sync must declare the permissions required by the
Nearby transport in `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission
        android:name="android.permission.BLUETOOTH_SCAN"
        android:usesPermissionFlags="neverForLocation" />
    <uses-permission
        android:name="android.permission.NEARBY_WIFI_DEVICES"
        android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

    <application>
        ...
    </application>
</manifest>
```

By default, `createMeshConfig()` requests missing runtime permissions. The mesh
network is created without waiting for the outcome; pass `onPermissionsGranted`
to get notified once the user has granted (some of) the permissions and call
`MeshSync.retryNetworks()` (via `SyncClient.mesh`) so the mesh retries starting
its network radios. If your app handles these runtime permissions itself, pass
`requestPermissions: false`:

```dart
final mesh = await createMeshConfig(
  'mesh-id',
  requestPermissions: false,
);
```

### iOS and macOS

On iOS and macOS, Mesh Sync requires the Swift Package Manager integration of
Flutter (the default since Flutter 3.44) and Xcode 16.3 or newer: the Nearby
transport is the `ObjectBoxMeshSync` add-on of the ObjectBox Swift Package,
which this plugin enables via the package's `MeshSync` trait. With the CocoaPods
integration (or older Xcode versions), the add-on is not part of the build and
`createMeshConfig()` throws an `UnsupportedError`.

Apps using Mesh Sync must add to their `Info.plist` (in `ios/Runner` or
`macos/Runner`):

- `NSLocalNetworkUsageDescription`: why the app uses the local network (Nearby
  discovers and connects to peers over Wi-Fi LAN).
- `NSBluetoothAlwaysUsageDescription`: why the app uses Bluetooth (Nearby also
  finds and connects to peers over Bluetooth).
- `NSBonjourServices` (required on iOS): the Bonjour service type Nearby derives
  from the mesh ID: `_<HASH>._tcp`, where `<HASH>` is the first 6 bytes of the
  SHA-256 of the mesh ID in upper-case hex (e.g. `_560B6041340C._tcp` for
  `test-mesh`; on a Mac: `printf %s test-mesh | shasum -a 256 | cut -c1-12`).

macOS apps are sandboxed: add the `com.apple.security.network.client` and
`com.apple.security.network.server` entitlements to
`macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`
(the Flutter template only has the server entitlement, and only for debug
builds) and, to use Bluetooth, `com.apple.security.device.bluetooth`. As for any
sandboxed macOS app using ObjectBox, an app group is required as well (see
`macosApplicationGroup` in the `Store` docs).

There are no runtime permissions to request upfront: the system prompts for
Local Network (and Bluetooth) access on first use, and the mesh retries starting
its network radios by itself. So `requestPermissions` and `onPermissionsGranted`
have no effect on these platforms. Note that until the Local Network prompt is
accepted, discovery and advertising are silently suppressed.
