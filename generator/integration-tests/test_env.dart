import 'dart:io';
import 'package:objectbox/objectbox.dart';
export 'package:objectbox/objectbox.dart';
import 'package:objectbox/internal.dart';
export 'package:objectbox/internal.dart';

class TestEnv<Entity> {
  static final dir = Directory('testdata');
  late final Store store;
  late final Box<Entity> box;

  TestEnv(ModelDefinition defs) {
    if (dir.existsSync()) dir.deleteSync(recursive: true);

    store = Store(defs, directory: dir.path);
    box = Box<Entity>(store);
  }

  void close() {
    store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
