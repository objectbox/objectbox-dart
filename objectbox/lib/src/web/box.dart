/// Web (dart2js/dart2wasm) stub for `native/box.dart`: mirrors its public API
/// so code compiles for web, but every operation throws [UnsupportedError]
/// until ObjectBox for web is available. See tracking issue #185.
// ignore_for_file: public_member_api_docs
library objectbox_web_box;

import 'package:meta/meta.dart';

import '../modelinfo/index.dart';
import '../query.dart';
import '../relations/info.dart';
import '../store.dart';
import '../transaction.dart';
import 'unsupported.dart';

enum PutMode { put, insert, update }

class Box<T> {
  factory Box(Store store) => throwUnsupportedOnWeb();

  int put(T object, {PutMode mode = PutMode.put}) => throwUnsupportedOnWeb();

  Future<int> putAsync(T object, {PutMode mode = PutMode.put}) =>
      throwUnsupportedOnWeb();

  Future<T> putAndGetAsync(T object, {PutMode mode = PutMode.put}) =>
      throwUnsupportedOnWeb();

  @Deprecated(
    "Use putAsync which supports relations, or for a large number of parallel calls putQueued.",
  )
  Future<int> putQueuedAwaitResult(T object, {PutMode mode = PutMode.put}) =>
      throwUnsupportedOnWeb();

  int putQueued(T object, {PutMode mode = PutMode.put}) =>
      throwUnsupportedOnWeb();

  List<int> putMany(List<T> objects, {PutMode mode = PutMode.put}) =>
      throwUnsupportedOnWeb();

  Future<List<int>> putManyAsync(
    List<T> objects, {
    PutMode mode = PutMode.put,
  }) =>
      throwUnsupportedOnWeb();

  Future<List<T>> putAndGetManyAsync(
    List<T> objects, {
    PutMode mode = PutMode.put,
  }) =>
      throwUnsupportedOnWeb();

  T? get(int id) => throwUnsupportedOnWeb();

  Future<T?> getAsync(int id) => throwUnsupportedOnWeb();

  List<T?> getMany(List<int> ids, {bool growableResult = false}) =>
      throwUnsupportedOnWeb();

  Future<List<T?>> getManyAsync(List<int> ids, {bool growableResult = false}) =>
      throwUnsupportedOnWeb();

  List<T> getAll() => throwUnsupportedOnWeb();

  Future<List<T>> getAllAsync() => throwUnsupportedOnWeb();

  QueryBuilder<T> query([Condition<T>? qc]) => throwUnsupportedOnWeb();

  int count({int limit = 0}) => throwUnsupportedOnWeb();

  bool isEmpty() => throwUnsupportedOnWeb();

  bool contains(int id) => throwUnsupportedOnWeb();

  bool containsMany(List<int> ids) => throwUnsupportedOnWeb();

  bool remove(int id) => throwUnsupportedOnWeb();

  Future<bool> removeAsync(int id) => throwUnsupportedOnWeb();

  int removeMany(List<int> ids) => throwUnsupportedOnWeb();

  Future<int> removeManyAsync(List<int> ids) => throwUnsupportedOnWeb();

  int removeAll() => throwUnsupportedOnWeb();

  Future<int> removeAllAsync() => throwUnsupportedOnWeb();
}

/// Internal only.
@internal
class InternalBoxAccess {
  static Box<T> create<T>(Store store, EntityDefinition<T> entity) =>
      throwUnsupportedOnWeb();

  static void close(Box box) => throwUnsupportedOnWeb();

  static int put<EntityT>(
    Box<EntityT> box,
    EntityT object,
    PutMode mode,
    Transaction? tx,
  ) =>
      throwUnsupportedOnWeb();

  static void relPut(Box box, int relationId, int sourceId, int targetId) =>
      throwUnsupportedOnWeb();

  static void relRemove(Box box, int relationId, int sourceId, int targetId) =>
      throwUnsupportedOnWeb();

  static List<EntityT> getRelated<EntityT>(Box<EntityT> box, RelInfo rel) =>
      throwUnsupportedOnWeb();
}
