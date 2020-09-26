import 'package:test/test.dart';
import 'package:objectbox/src/bindings/bindings.dart';
import 'package:objectbox/src/bindings/signatures.dart';
import 'entity.dart';
import 'entity2.dart';
import 'test_env.dart';
import 'objectbox.g.dart';
import 'dart:ffi';

// ignore_for_file: non_constant_identifier_names

/// Pointer.fromAddress(0) does not fire at all
Pointer<Void> randomPtr = Pointer.fromAddress(1337);

var callbackSingleTypeCounter = 0;
void callbackSingleType(Pointer<Void> user_data) {
  expect(user_data.address, randomPtr.address);
  callbackSingleTypeCounter++;
}

var callbackAnyTypeCounter = 0;
void callbackAnyType(Pointer<Void> user_data, Pointer<Uint32> mutated_ids, int mutated_count) {
  expect(user_data.address, randomPtr.address);
  callbackAnyTypeCounter++;
}

// dart callback signatures
typedef Single = void Function(Pointer<Void>);
typedef Any    = void Function(Pointer<Void>, Pointer<Uint32>, int);

class Observable {
  static Pointer<Void> singleObserver, anyObserver;

  static Single single;
  static Any    any;

  Store store;

  Observable.fromStore(this.store);

  static void _anyCallback(Pointer<Void> user_data, Pointer<Uint32> mutated_ids, int mutated_count) {
    any(user_data, mutated_ids, mutated_count);
  }

  static void _singleCallback(Pointer<Void> user_data) {
    single(user_data);
  }

  void observeSingleType(int entityId, Single fn, Pointer<Void> identifier) {
    single = fn;
    final callback = Pointer.fromFunction<obx_observer_single_type_native_t>(_singleCallback);
    singleObserver = bindings.obx_observe_single_type(store.ptr, entityId, callback, identifier);
  }

  void observe(Any fn, Pointer<Void> identifier) {
    any = fn;
    final callback = Pointer.fromFunction<obx_observer_t>(_anyCallback);
    anyObserver = bindings.obx_observe(store.ptr, callback, identifier);
  }
}

void main() async {
  TestEnv env;
  Box box;
  Store store;

  final testEntityId = getObjectBoxModel().model.findEntityByName('TestEntity').id.id;

  final simpleStringItems = <String>['One', 'Two', 'Three', 'Four', 'Five', 'Six'].map((s) =>
      TestEntity(tString: s)).toList().cast<TestEntity>();

  final simpleNumberItems = [1,2,3,4,5,6].map((s) =>
      TestEntity(tInt: s)).toList().cast<TestEntity>();

  setUp(() {
    env = TestEnv('observers');
    box = env.box;
    store = env.store;
  });

  /// Non static function can't be used for ffi, but you can call a dynamic function
  /// aka closure inside a static function
  //  void callbackAnyTypeNonStatic(Pointer<Void> user_data, Pointer<Uint32> mutated_ids, int mutated_count) {
  //    expect(user_data.address, 0);
  //    expect(mutated_count, 1);
  //  }

  test('Observe any entity with class member callback', () async {
    final o = Observable.fromStore(store);
    var putCount = 0;
    o.observe((Pointer<Void> user_data, Pointer<Uint32> mutated_ids, int mutated_count) {
      expect(user_data.address, randomPtr.address);
      putCount++;
    }, randomPtr);

    box.putMany(simpleStringItems);
    simpleStringItems.forEach((i) => box.put(i));
    simpleNumberItems.forEach((i) => box.put(i));

    bindings.obx_observer_close(Observable.anyObserver);
    expect(putCount, 13);
  });

  test('Observe a single entity with class member callback', () async {
    final o = Observable.fromStore(store);
    var putCount = 0;
    o.observeSingleType(testEntityId, (Pointer<Void> user_data) {
      putCount++;
    }, randomPtr);

    box.putMany(simpleStringItems);
    simpleStringItems.forEach((i) => box.put(i));
    simpleNumberItems.forEach((i) => box.put(i));

    bindings.obx_observer_close(Observable.singleObserver);
    expect(putCount, 13);
  });

  test('Observe any entity with static callback', () async {
    final callback = Pointer.fromFunction<obx_observer_t>(callbackAnyType);
    final observer = bindings.obx_observe(store.ptr, callback, Pointer.fromAddress(1337));

    box.putMany(simpleStringItems);

    box.remove(1);

    // update value
    final entity2 = box.get(2);
    entity2.tString = 'Dva';
    box.put(entity2);

    final box2 = Box<TestEntity2>(store);
    box2.put(TestEntity2());
    box2.remove(1);
    box2.put(TestEntity2());

    expect(callbackAnyTypeCounter, 6);
    bindings.obx_observer_close(observer);
  });

  test('Observe single entity', () async {
    final callback = Pointer.fromFunction<obx_observer_single_type_native_t>(callbackSingleType);
    final observer = bindings.obx_observe_single_type(store.ptr, testEntityId, callback, randomPtr);

    box.putMany(simpleStringItems);
    simpleStringItems.forEach((i) => box.put(i));
    simpleNumberItems.forEach((i) => box.put(i));

    expect(callbackSingleTypeCounter, 13);
    bindings.obx_observer_close(observer);
  });

  tearDown(() {
    env.close();
  });
}