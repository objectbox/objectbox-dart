import 'store.dart';
import 'sync.dart';

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

/// Global internal storage of sync clients - one client per store.
final Map<Store, SyncClient> SyncClientsStorage = {};

// Currently, either SyncClient or Observers can be used at the same time.
// TODO: lift this condition after #142 is fixed.
class SyncOrObserversExclusive {
  final _map = <Store, bool>{};

  void mark(Store store) {
    if (_map.containsKey(store)) {
      throw Exception(
          'Using observers/query streams in combination with SyncClient is currently not supported');
    }
    _map[store] = true;
  }

  void unmark(Store store) {
    _map.remove(store);
  }
}

final syncOrObserversExclusive = SyncOrObserversExclusive();
