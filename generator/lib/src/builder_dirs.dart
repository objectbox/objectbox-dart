import 'package:path/path.dart' as path;

import 'config.dart';

class BuilderDirs {
  /// The normalized path to the source code root directory.
  final String root;

  /// The normalized path to the output directory for generated code.
  final String out;

  BuilderDirs._(this.root, this.out);

  /// For [pathInSourceRoot] expects the path to a file in the source root
  /// directory (currently only lib or test are supported). It's used to
  /// determine the [root] source path and [out] path for generated code.
  /// A [config] may customize the [out] path relative to [root].
  factory BuilderDirs(String pathInSourceRoot, Config config) {
    // Paths from Config are supplied by the user and may contain duplicate
    // slashes or be empty: normalize all paths to not return duplicate or
    // trailing slashes to ensure they can be compared via strings.
    final root = path.normalize(path.dirname(pathInSourceRoot));
    final String out;
    if (root.endsWith('test')) {
      out = path.normalize('$root/${config.outDirTest}');
    } else if (root.endsWith('lib')) {
      out = path.normalize('$root/${config.outDirLib}');
    } else {
      throw ArgumentError('Is not lib or test directory: "$root"');
    }
    return BuilderDirs._(root, out);
  }
}
