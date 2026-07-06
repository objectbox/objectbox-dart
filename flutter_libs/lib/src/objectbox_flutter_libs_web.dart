import 'package:objectbox/objectbox.dart';

/// Stand-in for `dart:io`'s `Directory` on the web platform, where there is no
/// real file system. Only carries the [path] that generated `openStore()` code
/// passes to the [Store] constructor, which uses it as a logical database
/// name on web.
class WebStoreDirectory {
  /// The logical database name.
  final String path;

  /// Wrap a logical database name.
  const WebStoreDirectory(this.path);
}

/// Returns the default database location on web: there are no directories,
/// so this is just [Store.defaultDirectoryPath] used as a logical name.
Future<WebStoreDirectory> defaultStoreDirectory() async =>
    const WebStoreDirectory(Store.defaultDirectoryPath);

/// Does nothing on web (there is no native library to load). See the native
/// variant of this function for details.
Future<void> loadObjectBoxLibraryAndroidCompat() async {}
