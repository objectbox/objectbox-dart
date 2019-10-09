import "dart:io";
import "package:objectbox/objectbox.dart";

void Function() tearDownStorage(Store store, Box box) {
  return () {
    if (store != null) store.close();
    store = null;
    var dir = new Directory("objectbox");
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  };
}