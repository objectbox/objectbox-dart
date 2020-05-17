import "package:test/test.dart";
import "entity.dart";
import 'test_env.dart';
import 'objectbox.g.dart';
import "dart:ffi";
import "dart:io";
import "dart:async"; // TODO start to experiment with StreamController / yield / sink / Future

Pointer<Void> randomPtr = Pointer.fromAddress(1337);
Completer globalSingleCompleter = Completer();
Completer globalAnyCompleter = Completer();

void callbackSingleType(Pointer<Void> user_data) {
  expect(user_data.address, randomPtr.address);
  globalSingleCompleter.complete;
}

void callbackAnyType(Pointer<Void> user_data, Pointer<Uint32> mutated_idss, int mutated_count) {
  expect(user_data.address, randomPtr.address);
//  expect(mutated_ids.address, 0); // TODO
//  expect(mutated_count, 1); // TODO size of the array at mutated_idss
  globalAnyCompleter.complete;
}

typedef Single = void Function(Pointer<Void>);
typedef Any    = void Function(Pointer<Void>, Pointer<Uint32>, int);

/**
 * Initial idea, to support of whatever flavor of
 * reactive dart library (rxdart / stream)
 * user_data can be used to tag a callback function object
 */
class Observable /* extension Observable on Store... */ {
  static Completer completer, singleCompleter;

  static Pointer<Void> singleObserver, anyObserver;

  static Single single;
  static Any    any;

  Store store;

  Observable.fromStore(this.store);

  static void _anyCallback(Pointer<Void> user_data, Pointer<Uint32> mutated_ids, int mutated_count) {
    any(user_data, mutated_ids, mutated_count);
    completer.complete;
  }

  static void _singleCallback(Pointer<Void> user_data) {
    single(user_data);
    singleCompleter.complete;
  }

  // TODO plugin rx/stream framework
  // TODO allow multiple callbacks?
  void observeSingleType(int entityId, Single fn, Pointer<Void> identifier) {
    singleCompleter = Completer();
    single = fn;
    final callback = Pointer.fromFunction<obx_observer_single_type_t<Void>>(_singleCallback);
    singleObserver = bindings.obx_observe_single_type(store.ptr, entityId, callback, identifier);
  }

  // TODO plugin rx/stream framework
  // TODO allow >1 callbacks?
  void observe(Any fn, Pointer<Void> identifier) {
    completer = Completer();
    any = fn;
    final callback = Pointer.fromFunction<obx_observer_t<Void, Uint32>>(_anyCallback);
    anyObserver = bindings.obx_observe(store.ptr, callback, identifier);
  }

  Future<void> singleComplete() async {
    final willDispose = await singleCompleter.isCompleted;
    bindings.obx_observer_close(singleObserver);
  }

  Future<void> anyComplete() async {
    await completer.isCompleted;
    bindings.obx_observer_close(anyObserver);
  }
}

void main() async {
  TestEnv env;
  Box box;
  Store store;

  final testEntityId = getObjectBoxModel().model.findEntityByName("TestEntity").id.id;

  final List<TestEntity> simpleItems = <String>["One", "Two", "Three", "Four", "Five", "Six"].map((s) =>
      TestEntity(tString: s)).toList();

  setUp(() {
    env = TestEnv("observers");
    box = env.box;
    store = env.store;
  });

  /// Non static function can't be used for ffi
  //  void callbackAnyTypeNonStatic(Pointer<Void> user_data, Pointer<Uint32> mutated_ids, int mutated_count) {
  //    expect(user_data.address, 0);
  //    expect(mutated_count, 1);
  //  }

  test("Observe any entity with class member callback", () async {
    final o = Observable.fromStore(store);
    var putCount = 0;
    o.observe((Pointer<Void> user_data, Pointer<Uint32> mutated_ids, int mutated_count) {
      expect(user_data.address, randomPtr.address);
      print("test 1: $mutated_ids, $mutated_count");
      putCount++;
//      expect(mutated_ids, TODO);
//      expect(mutated_count, TODO);
    }, randomPtr);
    simpleItems.forEach((i) => box.put(i));
    box.putMany(simpleItems);
    await o.anyComplete();
    expect(putCount, 7);
  });

  test("Observe a single entity with class member callback", () async {
    final o = Observable.fromStore(store);
    var putCount = 0;
    o.observeSingleType(testEntityId, (Pointer<Void> user_data) {
      print("test 2");
//      expect(user_data.address, equals(randomPtr.address)); // never fails
      putCount++;
    }, randomPtr);
    simpleItems.forEach((i) => box.put(i));
    box.putMany(simpleItems);
    await o.singleComplete();
    expect(putCount, 7);
  });

  test("Observe any entity with static callback", () async {
    final callback = Pointer.fromFunction<obx_observer_t<Void, Uint32>>(callbackAnyType);
    final observer = bindings.obx_observe(store.ptr, callback, randomPtr);
    simpleItems.forEach((i) => box.put(i));
    box.putMany(simpleItems);
    await globalAnyCompleter.isCompleted;
    bindings.obx_observer_close(observer);
  });

  test("Observe single entity", () async {
    final callback = Pointer.fromFunction<obx_observer_single_type_t<Void>>(callbackSingleType);
    final observer = bindings.obx_observe_single_type(store.ptr, testEntityId, callback, randomPtr);
    box.putMany(simpleItems);
    simpleItems.forEach((i) => box.put(i));
    await globalSingleCompleter.isCompleted;
    bindings.obx_observer_close(observer);
  });

  tearDown(() {
    env.close();
  });
}