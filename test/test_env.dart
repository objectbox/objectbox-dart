import "dart:io";
import "package:objectbox/objectbox.dart";
import "entity.dart";

class TestEnv<Entity> {
  final Directory dir;
  Store store;
  Box<Entity> box;

  TestEnv(EntityDefinition<Entity> definition, String name) : dir = Directory("testdata-" + name) {
    if (dir.existsSync()) dir.deleteSync(recursive: true);

    store = Store([definition], directory: dir.path);
    box = Box<Entity>(store);
  }

  close() {
    store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
