/// This package contains platform-specific native libraries for flutter.
/// See the actual library implementation in package "objectbox".
library;

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

/// If on Android, iOS or macOS, invokes the `createMeshNetwork` platform
/// method passing [serviceId] and [requestPermissions] as arguments. Returns a
/// Future that on success completes with the handle to the native network
/// instance (what the handle points to differs by platform, see the caller).
///
/// See the `ObjectboxSyncFlutterLibsPlugin` documentation (Kotlin for Android,
/// Swift for iOS and macOS) for details on the arguments, the platform method
/// called in case requested permissions were granted (Android only; which
/// should be handled in a method call handler) and special error codes returned
/// (which will cause the Future returned by this to complete with a
/// [PlatformException]). If the platform plugin was built without a mesh
/// network implementation, the Future completes with a
/// [MissingPluginException].
Future<int?> _createMeshNetwork(
  String serviceId, {
  required bool requestPermissions,
}) async {
  if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
    return null; // Not implemented on other platforms.
  }
  return _platform.invokeMethod<int>('createMeshNetwork', {
    'serviceId': serviceId,
    'requestPermissions': requestPermissions,
  });
}

/// Creates a mesh sync configuration with the given options.
///
/// On Flutter Android, iOS and macOS this comes with an actual network
/// implementation (based on Google Nearby Connections). On iOS and macOS this
/// requires the Swift Package Manager integration of Flutter (see the README
/// of this package); otherwise this throws an [UnsupportedError].
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
/// On Android, this may request missing runtime permissions required by the
/// platform's mesh transport.
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
///
/// On iOS and macOS, there is nothing to request upfront: the system shows its
/// Local Network and Bluetooth prompts on first use and the mesh retries
/// starting its network radios by itself, so [requestPermissions] and
/// [onPermissionsGranted] are not used there (see the README of this package
/// for the Info.plist entries and entitlements an app needs).
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
  int? advertisingRetryMillis,
  int? advertisingRetryMaxMillis,
  int? connectDelayMillis,
  int? initialDiscoveryDurationSeconds,
  int? discoveryDurationSeconds,
  int? discoveryPauseSeconds,
  int? discoveryPauseJitterSeconds,
  int? txLogBatchSizeKb,
  int? txLogBatchMaxCount,
  int? txLogMaxAgeSeconds,
}) async {
  final mesh = obx_internal.MeshConfigInternal.createMeshConfig(
    meshId,
    maxConnectionCount: maxConnectionCount,
    backoffMillis: backoffMillis,
    evictionBackoffMillis: evictionBackoffMillis,
    randomSeed: randomSeed,
    requestTimeoutMillis: requestTimeoutMillis,
    advertisingDelayMillis: advertisingDelayMillis,
    advertisingRetryMillis: advertisingRetryMillis,
    advertisingRetryMaxMillis: advertisingRetryMaxMillis,
    connectDelayMillis: connectDelayMillis,
    initialDiscoveryDurationSeconds: initialDiscoveryDurationSeconds,
    discoveryDurationSeconds: discoveryDurationSeconds,
    discoveryPauseSeconds: discoveryPauseSeconds,
    discoveryPauseJitterSeconds: discoveryPauseJitterSeconds,
    txLogBatchSizeKb: txLogBatchSizeKb,
    txLogBatchMaxCount: txLogBatchMaxCount,
    txLogMaxAgeSeconds: txLogMaxAgeSeconds,
  );

  if (Platform.isAndroid) {
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

    // The Android plugin returns an internal network pointer.
    mesh.addNetworkInternalHandle(handle);
  } else if (Platform.isIOS || Platform.isMacOS) {
    // No permissions to request upfront on Apple platforms (see the docs
    // above), so the plugin ignores requestPermissions and never calls back.
    final int? handle;
    try {
      handle = await _createMeshNetwork(
        meshId,
        requestPermissions: requestPermissions,
      );
    } on MissingPluginException {
      // The Swift plugin only implements the method if it was built with the
      // mesh sync add-on of the ObjectBox Swift Package.
      throw UnsupportedError(
        'Mesh Sync is not available in this build: on iOS and macOS it '
        'requires the Swift Package Manager integration of Flutter and Xcode '
        '16.3 or newer (the CocoaPods integration does not include the mesh '
        'sync add-on).',
      );
    }
    if (handle == null || handle == 0) {
      throw StateError('Failed to create Apple Nearby mesh network');
    }

    // The Apple plugin returns an OBX_mesh_network handle (C mesh network API).
    mesh.addNetworkHandle(handle);
  }
  // Other platforms: no network implementation yet.

  return mesh;
}
