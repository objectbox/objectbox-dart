/// This package contains platform-specific native libraries for flutter.
/// See the actual library implementation in package "objectbox".
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';

/// Returns the default database directory inside this Flutter app's
/// `getApplicationDocumentsDirectory()`.
///
/// Note: on desktop platforms this returns a directory in the users documents
/// directory. It is advised to not use this then and instead create a directory
/// named specifically for your app.
Future<Directory> defaultStoreDirectory() async => Directory(
  '${(await getApplicationDocumentsDirectory()).path}/${Store.defaultDirectoryPath}',
);

const _platform = MethodChannel("objectbox_flutter_libs");

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
