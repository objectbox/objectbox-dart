import 'dart:ffi';

import 'package:objectbox/src/bindings/bindings.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'entity2.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

// ignore_for_file: non_constant_identifier_names

/// Pointer.fromAddress(0) does not fire at all
Pointer<Void> randomPtr = Pointer.fromAddress(1337);

var callbackSingleTypeCounter = 0;

void callbackSingleType(Pointer<Void> user_data) {
  expect(user_data.address, randomPtr.address);
  callbackSingleTypeCounter++;
}

var callbackAnyTypeCounter = 0;

void callbackAnyType(
    Pointer<Void> user_data, Pointer<Uint32> mutated_ids, int mutated_count) {
  expect(user_data.address, randomPtr.address);
  callbackAnyTypeCounter++;
}

// dart callback signatures
typedef Single = void Function(Pointer<Void>);
typedef Any = void Function(Pointer<Void>, Pointer<Uint32>, int);

class ObservableSingle {
  static /*late*/ Pointer<OBX_observer> observer;
  static /*late*/ Single single;
  Store store;

  ObservableSingle.fromStore(this.store);

  static void _singleCallback(Pointer<Void> user_data) {
    single(user_data);
  }

  void observeSingleType(int entityId, Single fn, Pointer<Void> identifier) {
    single = fn;
    final callback =
        Pointer.fromFunction<obx_observer_single_type>(_singleCallback);
    observer = C.observe_single_type(store.ptr, entityId, callback, identifier);
  }
}

class ObservableMany {
  static /*late*/ Pointer<OBX_observer> observer;
  static /*late*/ Any any;
  Store store;

  ObservableMany.fromStore(this.store);

  static void _anyCallback(
      Pointer<Void> user_data, Pointer<Uint32> mutated_ids, int mutated_count) {
    any(user_data, mutated_ids, mutated_count);
  }

  void observe(Any fn, Pointer<Void> identifier) {
    any = fn;
    final callback = Pointer.fromFunction<obx_observer>(_anyCallback);
    observer = C.observe(store.ptr, callback, identifier);
  }
}

void main() async {
  /*late final*/ TestEnv env;
  /*late final*/ Box<TestEntity> box;
  /*late final*/ Store store;

  final testEntityId =
      getObjectBoxModel().model.findEntityByName('TestEntity').id.id;

  final simpleStringItems = () => <String>[
        'One',
        'Two',
        'Three',
        'Four',
        'Five',
        'Six'
      ].map((s) => TestEntity(tString: s)).toList().cast<TestEntity>();

  final simpleNumberItems = () => [1, 2, 3, 4, 5, 6]
      .map((s) => TestEntity(tInt: s))
      .toList()
      .cast<TestEntity>();

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
    final o = ObservableMany.fromStore(store);
    var putCount = 0;
    o.observe((Pointer<Void> user_data, Pointer<Uint32> mutated_ids,
        int mutated_count) {
      expect(user_data.address, randomPtr.address);
      putCount++;
    }, randomPtr);

    box.putMany(simpleStringItems());
    simpleStringItems().forEach((i) => box.put(i));
    simpleNumberItems().forEach((i) => box.put(i));

    C.observer_close(ObservableMany.observer);
    expect(putCount, 13);
  });

  test('Observe a single entity with class member callback', () async {
    final o = ObservableSingle.fromStore(store);
    var putCount = 0;
    o.observeSingleType(testEntityId, (Pointer<Void> user_data) {
      putCount++;
    }, randomPtr);

    box.putMany(simpleStringItems());
    simpleStringItems().forEach((i) => box.put(i));
    simpleNumberItems().forEach((i) => box.put(i));

    C.observer_close(ObservableSingle.observer);
    expect(putCount, 13);
  });

  test('Observe any entity with static callback', () async {
    final callback = Pointer.fromFunction<obx_observer>(callbackAnyType);
    final observer = C.observe(store.ptr, callback, Pointer.fromAddress(1337));

    box.putMany(simpleStringItems());

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
    C.observer_close(observer);
  });

  test('Observe single entity', () async {
    final callback =
        Pointer.fromFunction<obx_observer_single_type>(callbackSingleType);
    final observer =
        C.observe_single_type(store.ptr, testEntityId, callback, randomPtr);

    box.putMany(simpleStringItems());
    simpleStringItems().forEach((i) => box.put(i));
    simpleNumberItems().forEach((i) => box.put(i));

    expect(callbackSingleTypeCounter, 13);
    C.observer_close(observer);
  });

  tearDown(() {
    env.close();
  });
}
