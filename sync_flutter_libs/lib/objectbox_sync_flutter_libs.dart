/// This package contains platform-specific native libraries for flutter.
/// See the actual library implementation in package "objectbox".

import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<Directory> defaultStoreDirectory() async =>
    await getApplicationDocumentsDirectory();
