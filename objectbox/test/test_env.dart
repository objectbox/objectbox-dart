import "package:objectbox/objectbox.dart";
import "entity.dart";

class TestEnv {
  final Directory dir;
  Store store;
  Box<TestEntity> box;

  TestEnv(String name) : dir = Directory("testdata-" + name) {
    if (dir.existsSync()) dir.deleteSync(recursive: true);

    store = Store([TestEntity_OBXDefs], directory: dir.path);
    box = Box<TestEntity>(store);
  }

  close() {
    store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
