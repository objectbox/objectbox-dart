import 'store.dart';

bool listContains<T>(List<T> list, T item) =>
    list.indexWhere((x) => x == item) != -1;

/// A list of observers of the Store.close() event.
///
/// Keeping this a global variable instead of a store field to avoid exposing.
class StoreCloseObserver {
  static final maps = <Store, Map<dynamic, void Function()>>{};

  /// Adds a listener to the [store.close()] event.
  static void addListener(Store store, dynamic key, void Function() listener) {
    if (!maps.containsKey(store)) {
      maps[store] = <dynamic, void Function()>{};
    }
    maps[store][key] = listener;
  }

  /// Removes a [store.close()] event listener.
  static void removeListener(Store store, dynamic key) {
    if (!maps.containsKey(store)) {
      return;
    }
    maps[store].remove(key);
    if (maps[store].isEmpty) {
      maps.remove(store);
    }
  }

  /// Collects and removes all listeners for the given store.
  static List<void Function()> removeAllListeners(Store store) {
    if (!maps.containsKey(store)) {
      return [];
    }
    final listeners = maps[store].values.toList(growable: false);
    maps.remove(store);
    return listeners;
  }
}
