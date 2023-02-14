import 'dart:ffi';

import '../store.dart';
import 'bindings/bindings.dart';
import 'bindings/helpers.dart';

/// A weak reference to a store that does not prevent the store from closing.
///
/// To use:
/// ```
/// final weakStore = WeakStore.get(store.configuration());
/// // Lock full store, this throws if that was closed already.
/// final store = weakStore.lock();
/// // Do Store operations.
/// store.close();
/// // Optional: if not longer needed, free the weak store reference.
/// // Note this is done automatically if the underlying store is closed.
/// weakStore.close();
/// ```
class WeakStore {
  /// Holds previously constructed weak stores by store ID for this isolate.
  static final _weakStoresCacheOfIsolate = <int, WeakStore>{};

  /// Based on the ID get an existing weak store, or null if there is none.
  static WeakStore? get(StoreConfiguration configuration) =>
      _weakStoresCacheOfIsolate[configuration.id];

  /// Based on the ID get an existing weak store, or create a new one.
  static WeakStore getOrCreate(StoreConfiguration configuration) {
    final existingWeakStore = get(configuration);
    if (existingWeakStore == null) {
      final newWeakStore = WeakStore(configuration);
      _weakStoresCacheOfIsolate[configuration.id] = newWeakStore;
      return newWeakStore;
    } else {
      return existingWeakStore;
    }
  }

  /// The store configuration used to create this weak reference.
  StoreConfiguration configuration;

  Pointer<OBX_weak_store>? _weakStorePtr;

  Pointer<OBX_weak_store> get _weakStorePtrSafe {
    final weakStorePtrBacking = _weakStorePtr;
    if (weakStorePtrBacking == null) throw StateError("Weak store is closed");
    return weakStorePtrBacking;
  }

  /// Create a weak reference to the store with the ID of the given
  /// configuration. This will throw if the store to reference is already
  /// closed.
  WeakStore(this.configuration) {
    final weakStorePtr = C.weak_store_by_id(configuration.id);
    checkObxPtr(weakStorePtr);
    _weakStorePtr = weakStorePtr;
  }

  /// Frees the native resources associated with this.
  ///
  /// Do not use any methods of this afterwards.
  void close() {
    final weakStorePtr = _weakStorePtr;
    if (weakStorePtr == null) return;
    C.weak_store_free(weakStorePtr);
    _weakStorePtr = null;
    _weakStoresCacheOfIsolate.remove(configuration.id);
  }

  /// Obtains a Store from a weak Store for short-time use.
  ///
  /// Will throw if the Store is already closed.
  /// Make sure to close the returned Store when done using it.
  Store lock() => StoreInternal.fromWeakStore(configuration, _weakStorePtrSafe);
}
