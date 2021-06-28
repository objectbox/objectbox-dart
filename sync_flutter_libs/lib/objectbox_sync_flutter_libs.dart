/// This package contains platform-specific native libraries for flutter.
/// See the actual library implementation in package "objectbox".

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Returns the default DB dir rooted in the current app's document directory.
Future<Directory> defaultStoreDirectory() async =>
    Directory((await getApplicationDocumentsDirectory()).path + '/objectbox');
