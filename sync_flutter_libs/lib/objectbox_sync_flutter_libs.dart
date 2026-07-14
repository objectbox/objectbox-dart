/// This package contains platform-specific native libraries for flutter.
/// See the actual library implementation in package "objectbox".
library objectbox_sync_flutter_libs;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:objectbox/internal.dart' as obx_internal;
import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';

/// Returns the default database directory inside this Flutter app's
/// `getApplicationDocumentsDirectory()`.
///
/// Note: on desktop platforms this returns a directory in the users documents
/// directory. It is advised to not use this then and instead create a directory
/// named specifically for your app.
Future<Directory> defaultStoreDirectory() async {
  return Directory(
    '${(await getApplicationDocumentsDirectory()).path}/${Store.defaultDirectoryPath}',
  );
}

const _platform = MethodChannel("objectbox_sync_flutter_libs");

/// If your Flutter app runs on Android 6 (or older) devices, call this before
/// using any ObjectBox APIs, to fix loading the native ObjectBox library.
///
/// If the device is running Android 6 (or older) this will try to load the
/// native library using Java APIs. Afterwards, calling ObjectBox APIs should
/// load the library successfully on the Dart/Flutter side.
///
/// See the [GitHub issue for details](https://github.com/objectbox/objectbox-dart/issues/369).
Future<void> loadObjectBoxLibraryAndroidCompat() async {
  if (!Platform.isAndroid) {
    // To support calling this in multi-platform Flutter apps
    // do nothing if not Android (plugins for other platforms do not
    // implement method below).
    return;
  }
  await _platform.invokeMethod<String>('loadObjectBoxLibrary');
}

Future<int?> _createMeshNetwork(
  String serviceId, {
  required bool requestPermissions,
}) async {
  if (!Platform.isAndroid) return null; // Not implemented on other platforms.
  return _platform.invokeMethod<int>('createMeshNetwork', {
    'serviceId': serviceId,
    'requestPermissions': requestPermissions,
  });
}

/// Creates a mesh sync configuration with the given options.
///
/// Only on Flutter Android this comes with an actual network implementation.
/// On other platforms, this returns a plain [MeshConfig],
/// which will not result in a working mesh sync yet.
///
/// Use like this:
///
/// ```dart
/// import 'package:objectbox/objectbox.dart';
/// import 'package:objectbox_sync_flutter_libs/objectbox_sync_flutter_libs.dart'
///     show createMeshConfig;
///
/// final mesh = await createMeshConfig('mesh-id');
/// final client = SyncClient(store, urls, credentials, mesh: mesh);
/// ```
///
/// This may request missing runtime permissions required by the platform's
/// mesh transport (e.g., required for Android).
/// The mesh network is created immediately, without waiting for the user to
/// grant the permissions. Once the user has granted (some of) the requested
/// permissions, [onPermissionsGranted] is called; it should call
/// [MeshSync.retryNetworks] (via [SyncClient.mesh]) once a sync client exists
/// so the mesh retries starting its network radios:
///
/// ```dart
/// SyncClient? client;
/// final mesh = await createMeshConfig('mesh-id',
///     onPermissionsGranted: () => client?.mesh?.retryNetworks());
/// client = SyncClient(store, urls, credentials, mesh: mesh);
/// ```
///
/// Pass [requestPermissions] as `false` if your app requests and grants these
/// permissions before calling this function.
Future<MeshConfig> createMeshConfig(
  String meshId, {
  bool requestPermissions = true,
  void Function()? onPermissionsGranted,
  int? maxConnectionCount,
  int? backoffMillis,
  int? evictionBackoffMillis,
  int? randomSeed,
  int? requestTimeoutMillis,
  int? advertisingDelayMillis,
  int? connectDelayMillis,
  int? initialDiscoveryDurationSeconds,
  int? discoveryDurationSeconds,
  int? discoveryPauseSeconds,
  int? discoveryPauseJitterSeconds,
  int? txLogBatchSizeKb,
  int? txLogBatchMaxCount,
}) async {
  final mesh = obx_internal.InternalSyncAccess.createMeshConfig(
    meshId,
    maxConnectionCount: maxConnectionCount,
    backoffMillis: backoffMillis,
    evictionBackoffMillis: evictionBackoffMillis,
    randomSeed: randomSeed,
    requestTimeoutMillis: requestTimeoutMillis,
    advertisingDelayMillis: advertisingDelayMillis,
    connectDelayMillis: connectDelayMillis,
    initialDiscoveryDurationSeconds: initialDiscoveryDurationSeconds,
    discoveryDurationSeconds: discoveryDurationSeconds,
    discoveryPauseSeconds: discoveryPauseSeconds,
    discoveryPauseJitterSeconds: discoveryPauseJitterSeconds,
    txLogBatchSizeKb: txLogBatchSizeKb,
    txLogBatchMaxCount: txLogBatchMaxCount,
  );

  if (!Platform.isAndroid) return mesh;

  // Get notified by the plugin once the user has granted (some of) the
  // requested permissions. Note: there can only be one method call handler
  // per channel, so the callback of the latest call to this function wins.
  _platform.setMethodCallHandler((MethodCall call) async {
    switch (call.method) {
      case 'onMeshSyncPermissionsGranted':
        onPermissionsGranted?.call();
      default:
        throw MissingPluginException('Unknown method ${call.method}');
    }
  });

  final handle = await _createMeshNetwork(
    meshId,
    requestPermissions: requestPermissions,
  );
  if (handle == null || handle == 0) {
    throw StateError('Failed to create Android Nearby mesh network');
  }

  obx_internal.InternalSyncAccess.addNetworkInternalHandle(mesh, handle);
  return mesh;
}
