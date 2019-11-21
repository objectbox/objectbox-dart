import "dart:io";
import "entity.dart";
import 'objectbox.g.dart';

class TestEnv {
  final Directory dir;
  Store store;
  Box<TestEntity> box;

  TestEnv(String name) : dir = Directory("testdata-" + name) {
    if (dir.existsSync()) dir.deleteSync(recursive: true);

    store = Store(getObjectBoxModel(), directory: dir.path);
    box = Box<TestEntity>(store);
  }

  close() {
    store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
