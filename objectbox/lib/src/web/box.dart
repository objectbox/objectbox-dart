/// Web implementation of Box, backed by WebStoreEngine (see engine.dart).
/// Mirrors the native put/relations protocol so the shared ToOne/ToMany code
/// works unchanged.
///
/// Note for maintainers: the analyzer resolves the conditional facades
/// ('../store.dart', '../transaction.dart') to the native variant, while this
/// library is only ever compiled together with the web variants. At the few
/// places where web types are passed to shared code whose signatures the
/// analyzer reads as native types, `// ignore: argument_type_not_assignable`
/// silences the resulting false positives - at web compile time the types are
/// identical.
// ignore_for_file: public_member_api_docs
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../flatbuffers.dart' as fb;
import '../box.dart' show PutMode;
import '../modelinfo/index.dart';
import '../query.dart';
import '../relations/info.dart';
import '../relations/to_many.dart';
import '../relations/to_one.dart';
import '../transaction.dart' show TxMode;
import 'engine.dart';
import 'store.dart';
import 'transaction.dart';
import 'unsupported.dart';

class Box<T> {
  final Store _store;
  final WebStoreEngine _engine;
  final EntityData _data;
  final EntityDefinition<T> _entity;
  final bool _hasToOneRelations;
  final bool _hasToManyRelations;
  final fb.Builder _builder = fb.Builder(initialSize: 256);

  factory Box(Store store) => store.box<T>();

  Box._(Store store, EntityDefinition<T> entity)
      : _store = store,
        _entity = entity,
        _engine = InternalStoreAccess.engine(store),
        _data = InternalStoreAccess.engine(store).entities[entity.model.id.id]!,
        _hasToOneRelations = entity.model.properties
            .any((p) => p.type == OBXPropertyType.Relation),
        _hasToManyRelations = entity.model.relations.isNotEmpty ||
            entity.model.backlinks.isNotEmpty;

  bool get _hasRelations => _hasToOneRelations || _hasToManyRelations;

  // ------------------------------------------------------------------- puts

  int put(T object, {PutMode mode = PutMode.put}) {
    if (_hasRelations) {
      return InternalStoreAccess.runInTransaction(
          _store, TxMode.write, (Transaction tx) => _put(object, mode, tx));
    }
    return _engine.runInTx(() => _put(object, mode, null));
  }

  Future<int> putAsync(T object, {PutMode mode = PutMode.put}) =>
      Future.microtask(() => put(object, mode: mode));

  Future<T> putAndGetAsync(T object, {PutMode mode = PutMode.put}) =>
      Future.microtask(() {
        put(object, mode: mode);
        return object;
      });

  @Deprecated(
      "Use putAsync which supports relations, or for a large number of parallel calls putQueued.")
  Future<int> putQueuedAwaitResult(T object, {PutMode mode = PutMode.put}) =>
      putAsync(object, mode: mode);

  /// On web there is no separate async queue: this is a normal (synchronous,
  /// in-memory) put; persistence happens via the write-behind queue.
  int putQueued(T object, {PutMode mode = PutMode.put}) =>
      put(object, mode: mode);

  List<int> putMany(List<T> objects, {PutMode mode = PutMode.put}) {
    if (objects.isEmpty) return [];
    return InternalStoreAccess.runInTransaction(
        _store,
        TxMode.write,
        (Transaction tx) =>
            objects.map((object) => _put(object, mode, tx)).toList());
  }

  Future<List<int>> putManyAsync(List<T> objects,
          {PutMode mode = PutMode.put}) =>
      Future.microtask(() => putMany(objects, mode: mode));

  Future<List<T>> putAndGetManyAsync(List<T> objects,
          {PutMode mode = PutMode.put}) =>
      Future.microtask(() {
        putMany(objects, mode: mode);
        return objects;
      });

  int _put(T object, PutMode mode, Transaction? tx) {
    if (_hasRelations && tx == null) {
      throw StateError(
          'Invalid state: can only use _put() on an entity with relations when'
          ' executing from inside a write transaction.');
    }
    if (_hasToOneRelations) {
      // There may be relation cycles, so get the ID first.
      if ((_entity.getId(object) ?? 0) == 0) {
        _entity.setId(object, _engine.reserveId(_data));
      }
      _putToOneRelFields(object, mode, tx!);
    }
    // OBXPutMode values: PUT=1, INSERT=2, UPDATE=3 (mode.index + 1).
    final id =
        _engine.checkPutId(_data, _entity.getId(object) ?? 0, mode.index + 1);
    if ((_entity.getId(object) ?? 0) == 0) _entity.setId(object, id);
    _builder.reset();
    _entity.objectToFB(object, _builder);
    // Copy: the builder's buffer is a view that is reused by the next put.
    final bytes = Uint8List.fromList(_builder.buffer);
    _engine.putRecord(_data, id, bytes);
    if (_hasToManyRelations) _putToManyRelFields(object, mode, tx!);
    return id;
  }

  void _putToOneRelFields(T object, PutMode mode, Transaction tx) {
    for (final toOne in _entity.toOneRelations(object)) {
      // ignore: argument_type_not_assignable
      toOne.applyToDb(_store, mode, tx);
    }
  }

  void _putToManyRelFields(T object, PutMode mode, Transaction tx) {
    _entity.toManyRelations(object).forEach((RelInfo info, ToMany rel) {
      // Always set relation info so ToMany applyToDb can be used after put.
      // ignore: argument_type_not_assignable
      InternalToManyAccess.setRelInfo<T>(rel, _store, info);
      if (InternalToManyAccess.hasPendingDbChanges(rel)) {
        // ignore: argument_type_not_assignable
        rel.applyToDb(existingStore: _store, mode: mode, tx: tx);
      }
    });
  }

  // ------------------------------------------------------------------ reads

  T _fromBytes(Uint8List bytes) => _entity.objectFromFB(
      // ignore: argument_type_not_assignable
      _store,
      ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes));

  T? get(int id) {
    final bytes = _engine.getRecord(_data, id);
    return bytes == null ? null : _fromBytes(bytes);
  }

  Future<T?> getAsync(int id) => Future.microtask(() => get(id));

  List<T?> getMany(List<int> ids, {bool growableResult = false}) {
    final result = List<T?>.filled(ids.length, null, growable: growableResult);
    for (var i = 0; i < ids.length; i++) {
      result[i] = get(ids[i]);
    }
    return result;
  }

  Future<List<T?>> getManyAsync(List<int> ids, {bool growableResult = false}) =>
      Future.microtask(() => getMany(ids, growableResult: growableResult));

  List<T> getAll() {
    _engine.checkOpen();
    return _data.records.values.map(_fromBytes).toList();
  }

  Future<List<T>> getAllAsync() => Future.microtask(getAll);

  /// Queries are not yet supported on web (phase 3 of web support).
  QueryBuilder<T> query([Condition<T>? qc]) => throwUnsupportedOnWeb();

  int count({int limit = 0}) {
    _engine.checkOpen();
    final length = _data.records.length;
    return limit > 0 && length > limit ? limit : length;
  }

  bool isEmpty() => count() == 0;

  bool contains(int id) {
    _engine.checkOpen();
    return _data.records.containsKey(id);
  }

  bool containsMany(List<int> ids) {
    _engine.checkOpen();
    return ids.every(_data.records.containsKey);
  }

  // ---------------------------------------------------------------- removes

  bool remove(int id) => _engine.runInTx(() => _engine.removeRecord(_data, id));

  Future<bool> removeAsync(int id) => Future.microtask(() => remove(id));

  int removeMany(List<int> ids) => _engine.runInTx(() {
        var removed = 0;
        for (final id in ids) {
          if (_engine.removeRecord(_data, id)) removed++;
        }
        return removed;
      });

  Future<int> removeManyAsync(List<int> ids) =>
      Future.microtask(() => removeMany(ids));

  int removeAll() => _engine.runInTx(() => _engine.removeAllRecords(_data));

  Future<int> removeAllAsync() => Future.microtask(removeAll);
}

/// Internal only.
@internal
class InternalBoxAccess {
  static Box<T> create<T>(Store store, EntityDefinition<T> entity) =>
      Box<T>._(store, entity);

  static void close(Box box) {
    // Nothing to release on web.
  }

  static int put<EntityT>(
          Box<EntityT> box, EntityT object, PutMode mode, Transaction? tx) =>
      box._put(object, mode, tx);

  static void relPut(Box box, int relationId, int sourceId, int targetId) =>
      box._engine.relPut(relationId, sourceId, targetId);

  static void relRemove(Box box, int relationId, int sourceId, int targetId) =>
      box._engine.relRemove(relationId, sourceId, targetId);

  static List<EntityT> getRelated<EntityT>(Box<EntityT> box, RelInfo rel) {
    final engine = box._engine;
    final List<int> ids;
    switch (rel.type) {
      case RelType.toMany:
        ids = engine.relTargets(rel.id, rel.objectId);
        break;
      case RelType.toOneBacklink:
        ids = engine.toOneBacklinkSources(box._data, rel.id, rel.objectId);
        break;
      case RelType.toManyBacklink:
        ids = engine.relBacklinkSources(rel.id, rel.objectId);
        break;
    }
    final result = <EntityT>[];
    for (final id in ids) {
      final object = box.get(id);
      if (object != null) result.add(object);
    }
    return result;
  }
}
