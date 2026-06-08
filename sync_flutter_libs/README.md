# ObjectBox database (with [Sync](https://objectbox.io/sync)) libraries for Flutter

[![pub package](https://img.shields.io/pub/v/objectbox_sync_flutter_libs.svg)](https://pub.dev/packages/objectbox_sync_flutter_libs)

This package provides the native ObjectBox database library, with the [Sync](https://objectbox.io/sync) 
client included, as a Flutter plugin for supported platforms.
Check the [Sync docs](https://sync.objectbox.io/) for more details.
You should add this package as a dependency when using [ObjectBox](https://pub.dev/packages/objectbox) with Flutter.

Configure the mesh Sync like this:

```dart
import 'package:objectbox/objectbox.dart';
import 'package:objectbox_sync_flutter_libs/objectbox_sync_flutter_libs.dart'
    show createMeshConfig;

final mesh = await createMeshConfig('mesh-id');
final client = SyncClient(store, urls, credentials, mesh: mesh);
```

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

By default, `createMeshConfig()` requests missing runtime permissions and waits
for the permission process to finish before creating the mesh network,
regardless of the outcome. If your app handles these runtime permissions
itself, pass `requestPermissions: false`:

```dart
final mesh = await createMeshConfig(
  'mesh-id',
  androidRequestPermissions: false,
);
```

See package [objectbox](https://pub.dev/packages/objectbox) for more details and information how to use it.
