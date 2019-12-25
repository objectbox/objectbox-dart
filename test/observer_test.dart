import "package:test/test.dart";
import "package:objectbox/objectbox.dart";
import "entity.dart";
import 'test_env.dart';
import 'objectbox.g.dart';
import "dart:ffi";
import "dart:io";

typedef obx_observer_t<U extends NativeType, T extends NativeType> = U Function(Pointer<Void> user_data, Pointer<Uint32> entity_id, T type_ids_count);
typedef obx_observer_single_type_t<U extends NativeType> = U Function(Pointer<Void> user_data);

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

  test("Trigger observer of any entity with class member callback", () {
    final observer = bindings.obx_observe(store.ptr, Pointer.fromFunction<obx_observer_t<Void, Uint32>>(Meh.memberCallbackAnyType), Pointer.fromAddress(0));
    box.putMany(simpleItems);
    bindings.obx_observer_close(observer);
  });

  test("Trigger observer of any entity with static callback", () {
    final observer = bindings.obx_observe(store.ptr, Pointer.fromFunction<obx_observer_t<Void, Uint32>>(callbackAnyType), Pointer.fromAddress(0));
    box.putMany(simpleItems);
    bindings.obx_observer_close(observer);
  });

  test("Trigger single entity observer", () {
    final observer = bindings.obx_observe_single_type(store.ptr, testEntityId, Pointer.fromFunction<obx_observer_single_type_t<Void>>(callbackSingleType), Pointer.fromAddress(0));
    box.putMany(simpleItems);
    bindings.obx_observer_close(observer);
  });

  tearDown(() {
    env.close();
  });
}