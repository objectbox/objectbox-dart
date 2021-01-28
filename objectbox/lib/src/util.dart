import 'store.dart';
import 'sync.dart';

bool listContains<T>(List<T> list, T item) =>
    list.indexWhere((x) => x == item) != -1;

/// Global internal storage of sync clients - one client per store.
final Map<Store, SyncClient> syncClientsStorage = {};

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
