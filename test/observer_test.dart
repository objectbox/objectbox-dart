import "package:test/test.dart";
import "entity.dart";
import 'test_env.dart';
import 'objectbox.g.dart';
import "dart:ffi";
import "dart:io";
import "dart:async"; // TODO start to experiment with StreamController / yield / sink / Future

void writeToFile(String input) {
  final file = File("observers-debug.txt");
  final sink = file.openWrite(mode:FileMode.APPEND);
  sink.write("${new DateTime.now()} $input\n");

  // Close the IOSink to free system resources.
  sink.close();
}

void callbackSingleType(Pointer<Void> user_data) {
  expect(user_data.address, 0);
  writeToFile("callbackSingleType");
}

void callbackAnyType(Pointer<Void> user_data, Pointer<Uint32> entity_id, int type_ids_count) {
  expect(user_data.address, 0);
  expect(type_ids_count, 1);
  writeToFile("callbackAnyType");
}

class Meh {
  static void memberCallbackAnyType(Pointer<Void> user_data, Pointer<Uint32> entity_id, int type_ids_count) {
    expect(user_data.address, 0);
    expect(type_ids_count, 1);
    writeToFile("memberCallbackAnyType");
  }
}

void main() {
  TestEnv env;
  Box box;
  Store store;

  final testEntityId = getObjectBoxModel().model.findEntityByName("TestEntity").id.id;

  final List<TestEntity> simpleItems =
  ["One", "Two", "Three", "Four", "Five", "Six"].map((s) =>
      TestEntity(tString: s)).toList();

  setUp(() {
    env = TestEnv("observers");
    box = env.box;
    store = env.store;
  });

  /// Non static function can't be used for ffi
  //  void callbackAnyTypeNonStatic(Pointer<Void> user_data, Pointer<Uint32> entity_id, int type_ids_count) {
  //    expect(user_data.address, 0);
  //    expect(type_ids_count, 1);
  //  }

  test("Observe any entity with class member callback", () {
    final callback = Pointer.fromFunction<obx_observer_t<Void, Uint32>>(Meh.memberCallbackAnyType);
    final observer = bindings.obx_observe(store.ptr, callback, Pointer.fromAddress(0));
    simpleItems.forEach((i) => box.put(i));
    box.putMany(simpleItems);
    bindings.obx_observer_close(observer);
  });

  test("Observe any entity with static callback", () {
    final callback = Pointer.fromFunction<obx_observer_t<Void, Uint32>>(callbackAnyType);
    final observer = bindings.obx_observe(store.ptr, callback, Pointer.fromAddress(0));
    simpleItems.forEach((i) => box.put(i));
    box.putMany(simpleItems);
    bindings.obx_observer_close(observer);
  });

  test("Observe single entity", () {
    final callback = Pointer.fromFunction<obx_observer_single_type_t<Void>>(callbackSingleType);
    final observer = bindings.obx_observe_single_type(store.ptr, testEntityId, callback, Pointer.fromAddress(0));
    box.putMany(simpleItems);
    simpleItems.forEach((i) => box.put(i));
    bindings.obx_observer_close(observer);
  });

  tearDown(() {
    env.close();
  });
}