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

// Keep method channel for later use
// ignore: unused_element
const _platform = MethodChannel("objectbox_flutter_libs");
