import 'dart:async';
import 'dart:ffi';
import 'bindings/bindings.dart';
import 'bindings/signatures.dart';

import 'store.dart';
import 'query/query.dart';

// ignore_for_file: non_constant_identifier_names

// dart callback signature
typedef Any = void Function(Pointer<Void>, Pointer<Uint32>, int);

class Observable {

  static final anyObserver = <int, Pointer<Void>>{};
  static final any = <int, Any>{}; // radix? > tree?

  // sync:true -> ObjectBoxException: 10001 TX is not active anymore: #101
  static final controller = StreamController<int>.broadcast();

  static void _anyCallback(Pointer<Void> user_data, Pointer<Uint32> mutated_ids, int mutated_count) {
    for(var i=0; i<mutated_count; i++) {
      // call schema's callback
      if (any.containsKey(mutated_ids[i])) {
        any[mutated_ids[i]](user_data, mutated_ids, mutated_count);
      }
    }
  }

  static void subscribe(Store store) {
    final callback = Pointer.fromFunction<obx_observer_t>(_anyCallback);
    anyObserver[store.ptr.address] = bindings.obx_observe(store.ptr, callback, store.ptr);
  }

  // #53 ffi:Pointer finalizer
  static void unsubscribe(Store store) {
    if (!anyObserver.containsKey(store.ptr.address)) {
      return;
    }
    bindings.obx_observer_close(anyObserver[store.ptr.address]);
    anyObserver.remove(store.ptr.address);
  }
}

extension ObservableStore on Store {
  void subscribe () { Observable.subscribe(this); }
  void unsubscribe () { Observable.unsubscribe(this); }
}

extension Streamable<T> on Query<T> {
  void _setup() {
    if (!Observable.anyObserver.containsKey(store.ptr)) {
      store.subscribe();
    }

    // Assume consensus on entityId over all available Stores
    Observable.any[entityId] ??= (u, _, __) {
      // dummy value to trigger an event
      Observable.controller.add(u.address);
    };
  }

  Stream<List<T>> findStream({int offset = 0, int limit = 0}) {
    _setup();
    return Observable.controller.stream
        .map((_) => find(offset:offset, limit:limit));
  }

  /// Use this for Query Property
  Stream<Query<T>> get stream {
    _setup();
    return Observable.controller.stream
        .map((_) => this);
  }
}