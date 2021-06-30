import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../common.dart';
import '../modelinfo/index.dart';
import '../relations/info.dart';
import '../relations/to_many.dart';
import '../relations/to_one.dart';
import '../store.dart';
import '../transaction.dart';
import 'bindings/bindings.dart';
import 'bindings/flatbuffers.dart';
import 'bindings/helpers.dart';
import 'query/query.dart';
import 'transaction.dart';

/// Box put (write) mode.
enum PutMode {
  /// Insert (if given object's ID is zero) or update an existing object.
  put,

  /// Insert a new object.
  insert,

  /// Update an existing object, fails if the given ID doesn't exist.
  update,
}

/// A Box instance gives you access to objects of a particular type.
/// You get Box instances via [Store.box()] or [Box(Store)].
///
/// For example, if you have User and Order entities, you need two Box objects
/// to interact with them:
/// ```dart
/// Box<User> userBox = store.box();
/// Box<Order> orderBox = store.box();
/// ```
class Box<T> {
  final Store _store;
  final Pointer<OBX_box> _cBox;
  final EntityDefinition<T> _entity;
  final bool _hasToOneRelations;
  final bool _hasToManyRelations;
  final _builder = BuilderWithCBuffer();
  _AsyncBoxHelper? _async;

  /// Create a box for an Entity.
  factory Box(Store store) => store.box();

  Box._(this._store, this._entity)
      : _hasToOneRelations = _entity.model.properties
            .any((ModelProperty prop) => prop.isRelation),
        _hasToManyRelations = _entity.model.relations.isNotEmpty ||
            _entity.model.backlinks.isNotEmpty,
        _cBox = C.box(InternalStoreAccess.ptr(_store), _entity.model.id.id) {
    checkObxPtr(_cBox, 'failed to create box');
  }

  bool get _hasRelations => _hasToOneRelations || _hasToManyRelations;

  /// Puts the given Object in the box (aka persisting it).
  ///
  /// If this is a new object (its ID property is 0), a new ID will be assigned
  /// to the object (and returned).
  ///
  /// If the object with given was already in the box, it will be overwritten.
  ///
  /// Performance note: consider [putMany] to put several objects at once.
  int put(T object, {PutMode mode = PutMode.put}) {
    if (_hasRelations) {
      return InternalStoreAccess.runInTransaction(
          _store, TxMode.write, (Transaction tx) => _put(object, mode, tx));
    } else {
      return _put(object, mode, null);
    }
  }

  /// Puts the given object in the box (persisting it) asynchronously.
  ///
  /// The returned future completes with an ID of the object. If it is a new
  /// object (its ID property is 0), a new ID will be assigned to the object
  /// argument, after the returned [Future] completes.
  ///
  /// In extreme scenarios (e.g. having hundreds of thousands async operations
  /// per second), this may fail as internal queues fill up if the disk can't
  /// keep up. However, this should not be a concern for typical apps.
  /// The returned future may also complete with an error if the put failed
  /// for another reason, for example a unique constraint violation. In that
  /// case the [object]'s id field remains unchanged (0 if it was a new object).
  ///
  /// See also [putQueued] which doesn't return a [Future] but a pre-allocated
  /// ID immediately, even though the actual database put operation may fail.
  Future<int> putAsync(T object, {PutMode mode = PutMode.put}) async =>
      // Wrap with [Future.sync] to avoid mixing sync and async errors.
      // Note: doesn't seem to decrease performance at all.
      // https://dart.dev/guides/libraries/futures-error-handling#potential-problem-accidentally-mixing-synchronous-and-asynchronous-errors
      Future.sync(() async {
        if (_hasRelations) {
          throw UnsupportedError(
              'putAsync() is currently not supported on entity '
              '${T.toString()} because it has relations.');
        }
        _async ??= _AsyncBoxHelper(this);

        // Note: we can use the shared flatbuffer object, because:
        // https://dart.dev/codelabs/async-await#execution-flow-with-async-and-await
        // > An async function runs synchronously until the first await keyword.
        // > This means that within an async function body, all synchronous code
        // > before the first await keyword executes immediately.
        _builder.fbb.reset();
        var id = _entity.objectToFB(object, _builder.fbb);
        final newId = _async!.put(id, _builder, mode);
        _builder.resetIfLarge(); // reset before `await`
        if (id == 0) {
          // Note: if the newId future completes with an error, ID isn't set.
          _entity.setId(object, await newId);
        }
        return newId;
      });

  /// Schedules the given object to be put later on, by an asynchronous queue.
  ///
  /// The actual database put operation may fail even if this function returned
  /// normally (and even if it returned a new ID for a new object). For example
  /// if the database put failed because of a unique constraint violation.
  /// Therefore, you should make sure the data you put is correct and you have
  /// a fall back in place even if it eventually failed.
  ///
  /// In extreme scenarios (e.g. having hundreds of thousands async operations
  /// per second), this may fail as internal queues fill up if the disk can't
  /// keep up. However, this should not be a concern for typical apps.
  ///
  /// See also [putAsync] which returns a [Future] that only completes after an
  /// actual database put was successful.
  /// Use [Store.awaitAsyncCompletion] and [Store.awaitAsyncSubmitted] to wait
  /// until all operations have finished.
  int putQueued(T object, {PutMode mode = PutMode.put}) {
    if (_hasRelations) {
      throw UnsupportedError('putQueued() is currently not supported on entity '
          '${T.toString()} because it has relations.');
    }
    _async ??= _AsyncBoxHelper(this);

    _builder.fbb.reset();
    var id = _entity.objectToFB(object, _builder.fbb);
    final newId = C.async_put_object4(_async!._cAsync, _builder.bufPtr,
        _builder.fbb.size, _getOBXPutMode(mode));
    id = _handlePutObjectResult(object, id, newId);
    _builder.resetIfLarge();
    return newId;
  }

  int _put(T object, PutMode mode, Transaction? tx) {
    if (_hasRelations) {
      if (tx == null) {
        throw StateError(
            'Invalid state: can only use _put() on an entity with relations when executing from inside a write transaction.');
      }
      if (_hasToOneRelations) {
        // In this case, there may be relation cycles so get the ID first.
        if ((_entity.getId(object) ?? 0) == 0) {
          final newId = C.box_id_for_put(_cBox, 0);
          if (newId == 0) throwLatestNativeError(context: 'id-for-put failed');
          _entity.setId(object, newId);
        }
        _putToOneRelFields(object, mode, tx);
      }
    }
    _builder.fbb.reset();
    var id = _entity.objectToFB(object, _builder.fbb);
    final data = _builder.bufPtr;
    print(_builder.fbb.size);
    // for (int i = 0; i < 5; i++) {
      print(data.cast<Uint8>().elementAt(4).value);
    // }
    // print(data.cast<Uint8>().asTypedList(_builder.fbb.size));
    return 0;
    final newId = C.box_put_object4(
        _cBox, data, _builder.fbb.size, _getOBXPutMode(mode));
    id = _handlePutObjectResult(object, id, newId);
    if (_hasToManyRelations) _putToManyRelFields(object, mode, tx!);
    _builder.resetIfLarge();
    return id;
  }

  /// Puts the given [objects] into this Box in a single transaction.
  ///
  /// Returns a list of all IDs of the inserted Objects.
  List<int> putMany(List<T> objects, {PutMode mode = PutMode.put}) {
    if (objects.isEmpty) return [];

    final putIds = List<int>.filled(objects.length, 0);

    InternalStoreAccess.runInTransaction(_store, TxMode.write,
        (Transaction tx) {
      if (_hasToOneRelations) {
        objects.forEach((object) => _putToOneRelFields(object, mode, tx));
      }

      final cursor = tx.cursor(_entity);
      final cMode = _getOBXPutMode(mode);
      for (var i = 0; i < objects.length; i++) {
        final object = objects[i];
        _builder.fbb.reset();
        final id = _entity.objectToFB(object, _builder.fbb);
        final newId = C.cursor_put_object4(
            cursor.ptr, _builder.bufPtr, _builder.fbb.size, cMode);
        putIds[i] = _handlePutObjectResult(object, id, newId);
      }

      if (_hasToManyRelations) {
        objects.forEach((object) => _putToManyRelFields(object, mode, tx));
      }
      _builder.resetIfLarge();
    });

    return putIds;
  }

  // Checks if native obx_*_put_object() was successful (result is a valid ID).
  // Sets the given ID on the object if previous ID was zero (new object).
  @pragma('vm:prefer-inline')
  int _handlePutObjectResult(T object, int prevId, int result) {
    if (result == 0) throwLatestNativeError(context: 'object put failed');
    if (prevId == 0) _entity.setId(object, result);
    return result;
  }

  /// Retrieves the stored object with the ID [id] from this box's database.
  /// Returns null if an object with the given ID doesn't exist.
  T? get(int id) => InternalStoreAccess.runInTransaction(
      _store, TxMode.read, (Transaction tx) => tx.cursor(_entity).get(id));

  /// Returns a list of [ids.length] Objects of type T, each corresponding to
  /// the location of its ID in [ids]. Non-existent IDs become null.
  ///
  /// Pass growableResult: true for the resulting list to be growable.
  List<T?> getMany(List<int> ids, {bool growableResult = false}) {
    final result = List<T?>.filled(ids.length, null, growable: growableResult);
    if (ids.isEmpty) return result;
    return InternalStoreAccess.runInTransaction(_store, TxMode.read,
        (Transaction tx) {
      final cursor = tx.cursor(_entity);
      for (var i = 0; i < ids.length; i++) {
        final object = cursor.get(ids[i]);
        if (object != null) result[i] = object;
      }
      return result;
    });
  }

  /// Returns all stored objects in this Box.
  List<T> getAll() => InternalStoreAccess.runInTransaction(_store, TxMode.read,
          (Transaction tx) {
        final cursor = tx.cursor(_entity);
        final result = <T>[];
        var code =
            C.cursor_first(cursor.ptr, cursor.dataPtrPtr, cursor.sizePtr);
        while (code != OBX_NOT_FOUND) {
          checkObx(code);
          result.add(_entity.objectFromFB(_store, cursor.readData));
          code = C.cursor_next(cursor.ptr, cursor.dataPtrPtr, cursor.sizePtr);
        }
        return result;
      });

  /// Returns a builder to create queries for Object matching supplied criteria.
  @pragma('vm:prefer-inline')
  QueryBuilder<T> query([Condition<T>? qc]) =>
      QueryBuilder<T>(_store, _entity, qc);

  /// Returns the count of all stored Objects in this box.
  /// If [limit] is not zero, stops counting at the given limit.
  int count({int limit = 0}) {
    final count = malloc<Uint64>();
    try {
      checkObx(C.box_count(_cBox, limit, count));
      return count.value;
    } finally {
      malloc.free(count);
    }
  }

  /// Returns true if no objects are in this box.
  bool isEmpty() {
    final isEmpty = malloc<Uint8>();
    try {
      checkObx(C.box_is_empty(_cBox, isEmpty));
      return isEmpty.value == 1;
    } finally {
      malloc.free(isEmpty);
    }
  }

  /// Returns true if this box contains an Object with the ID [id].
  bool contains(int id) {
    final contains = malloc<Uint8>();
    try {
      checkObx(C.box_contains(_cBox, id, contains));
      return contains.value == 1;
    } finally {
      malloc.free(contains);
    }
  }

  /// Returns true if this box contains objects with all of the given [ids].
  bool containsMany(List<int> ids) {
    final contains = malloc<Uint8>();
    try {
      return executeWithIdArray(ids, (ptr) {
        checkObx(C.box_contains_many(_cBox, ptr, contains));
        return contains.value == 1;
      });
    } finally {
      malloc.free(contains);
    }
  }

  /// Removes (deletes) the Object with the given [id]. Returns true if the
  /// object was present (and thus removed), otherwise returns false.
  bool remove(int id) {
    final err = C.box_remove(_cBox, id);
    if (err == OBX_NOT_FOUND) return false;
    checkObx(err); // throws on other errors
    return true;
  }

  /// Removes (deletes) by ID, returning a list of IDs of all removed Objects.
  int removeMany(List<int> ids) {
    final countRemoved = malloc<Uint64>();
    try {
      return executeWithIdArray(ids, (ptr) {
        checkObx(C.box_remove_many(_cBox, ptr, countRemoved));
        return countRemoved.value;
      });
    } finally {
      malloc.free(countRemoved);
    }
  }

  /// Removes (deletes) ALL Objects in a single transaction.
  int removeAll() {
    final removedItems = malloc<Uint64>();
    try {
      checkObx(C.box_remove_all(_cBox, removedItems));
      return removedItems.value;
    } finally {
      malloc.free(removedItems);
    }
  }

  void _putToOneRelFields(T object, PutMode mode, Transaction tx) {
    _entity.toOneRelations(object).forEach((ToOne rel) {
      if (!rel.hasValue) return;
      rel.attach(_store);
      // put new objects
      if (rel.targetId == 0) {
        rel.targetId =
            InternalToOneAccess.targetBox(rel)._put(rel.target, mode, tx);
      }
    });
  }

  void _putToManyRelFields(T object, PutMode mode, Transaction tx) {
    _entity.toManyRelations(object).forEach((RelInfo info, ToMany rel) {
      if (InternalToManyAccess.hasPendingDbChanges(rel)) {
        InternalToManyAccess.setRelInfo(rel, _store, info, this);
        rel.applyToDb(mode: mode, tx: tx);
      }
    });
  }
}

@pragma('vm:prefer-inline')
int __getOBXPutMode(PutMode mode) => mode.index + 1;

@pragma('vm:prefer-inline')
int _getOBXPutMode(PutMode mode) {
  assert(__getOBXPutMode(PutMode.put) == OBXPutMode.PUT);
  assert(__getOBXPutMode(PutMode.insert) == OBXPutMode.INSERT);
  assert(__getOBXPutMode(PutMode.update) == OBXPutMode.UPDATE);
  assert(PutMode.values.length == 3);
  return __getOBXPutMode(mode);
}

class _AsyncBoxHelper {
  final Pointer<OBX_async> _cAsync;

  _AsyncBoxHelper(Box box) : _cAsync = C.async_1(box._cBox) {
    initializeDartAPI();
  }

  Future<int> put(int id, BuilderWithCBuffer fbb, PutMode mode) async {
    final port = ReceivePort();
    final newId = C.dartc_async_put_object(_cAsync, port.sendPort.nativePort,
        fbb.bufPtr, fbb.fbb.size, _getOBXPutMode(mode));

    final completer = Completer<int>();

    // Zero is returned to indicate an immediate error, object won't be stored.
    if (newId == 0) {
      port.close();
      try {
        throwLatestNativeError(context: 'putAsync failed');
      } catch (e) {
        completer.completeError(e);
      }
    }

    port.listen((dynamic message) {
      if (!completer.isCompleted) {
        // Null is sent if the put was successful (there is no error, thus NULL)
        if (message == null) {
          completer.complete(newId);
        } else if (message is String) {
          completer.completeError(message.startsWith('Unique constraint')
              ? UniqueViolationException(message)
              : ObjectBoxException(message));
        } else {
          completer.completeError(ObjectBoxException(
              'Unknown message type (${message.runtimeType}: $message'));
        }
      }
      port.close();
    });
    return completer.future;
  }
}

/// Internal only.
@internal
class InternalBoxAccess {
  /// Create a box in the store for the given entity.
  static Box<T> create<T>(Store store, EntityDefinition<T> entity) =>
      Box._(store, entity);

  /// Close the box, freeing resources.
  static void close(Box box) => box._builder.clear();

  /// Put the object in a given transaction.
  @pragma('vm:prefer-inline')
  static int put<EntityT>(
          Box<EntityT> box, EntityT object, PutMode mode, Transaction? tx) =>
      box._put(object, mode, tx);

  /// Put a standalone relation.
  @pragma('vm:prefer-inline')
  static void relPut(
    Box box,
    int relationId,
    int sourceId,
    int targetId,
  ) =>
      checkObx(C.box_rel_put(box._cBox, relationId, sourceId, targetId));

  /// Remove a standalone relation entry between two objects.
  @pragma('vm:prefer-inline')
  static void relRemove(
    Box box,
    int relationId,
    int sourceId,
    int targetId,
  ) =>
      checkObx(C.box_rel_remove(box._cBox, relationId, sourceId, targetId));

  /// Read all objects in this Box related to the given object.
  /// Similar to box.getMany() but loads the OBX_id_array and reads objects
  /// in a single Transaction, ensuring consistency. And it's a little more
  /// efficient for not unpacking the id array to a dart list.
  static List<EntityT> getRelated<EntityT>(Box<EntityT> box, RelInfo rel) =>
      InternalStoreAccess.runInTransaction(box._store, TxMode.read,
          (Transaction tx) {
        Pointer<OBX_id_array> cIdsPtr;
        switch (rel.type) {
          case RelType.toMany:
            cIdsPtr = C.box_rel_get_ids(box._cBox, rel.id, rel.objectId);
            break;
          case RelType.toOneBacklink:
            cIdsPtr = C.box_get_backlink_ids(box._cBox, rel.id, rel.objectId);
            break;
          case RelType.toManyBacklink:
            cIdsPtr =
                C.box_rel_get_backlink_ids(box._cBox, rel.id, rel.objectId);
            break;
          default:
            throw UnimplementedError('Invalid relation type ${rel.type}');
        }
        checkObxPtr(cIdsPtr);
        final result = <EntityT>[];
        try {
          final cIds = cIdsPtr.ref;
          if (cIds.count > 0) {
            final cursor = tx.cursor(box._entity);
            for (var i = 0; i < cIds.count; i++) {
              final code = C.cursor_get(
                  cursor.ptr, cIds.ids[i], cursor.dataPtrPtr, cursor.sizePtr);
              if (code != OBX_NOT_FOUND) {
                checkObx(code);
                result
                    .add(box._entity.objectFromFB(box._store, cursor.readData));
              }
            }
          }
        } finally {
          C.id_array_free(cIdsPtr);
        }
        return result;
      });
}
