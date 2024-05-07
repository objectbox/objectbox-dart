import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../annotations.dart';
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

  /// Pointer to the native instance. Use [_ptr] for safe access instead.
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

  @pragma("vm:prefer-inline")
  Pointer<OBX_box> get _ptr {
    // Box does not have its own closed state as the native store is managing
    // the box pointers.
    _store.checkOpen();
    return _cBox;
  }

  bool get _hasRelations => _hasToOneRelations || _hasToManyRelations;

  /// Puts the given [object] and returns its (new) ID.
  ///
  /// This means that if its [Id] property is 0 or null, it is inserted as a new
  /// object and assigned the next available ID. For example, if there is an
  /// object with ID 1 and another with ID 100, it will be assigned ID 101. The
  /// new ID is also set on the given object before this returns.
  ///
  /// If instead the object has an assigned ID set, if an object with the same
  /// ID exists it is updated. Otherwise, it is inserted with that ID.
  ///
  /// If the ID was not assigned before a [StorageException] is thrown.
  ///
  /// When the object contains [ToOne] or [ToMany] relations, they are created
  /// (or updated) to point to the (new) target objects.
  /// The target objects themselves are typically not updated or removed.
  /// To do so, put or remove them using their [Box].
  /// However, for convenience, if a target object is new, it will be inserted
  /// and assigned an ID in its Box before creating or updating the relation.
  /// Also, for ToMany relations based on a [Backlink] from a ToOne, the target
  /// objects are updated (to store changes in the linked ToOne relation).
  ///
  /// Change [mode] to specify explicitly that only an insert or update should
  /// occur.
  ///
  /// See [putMany] to put several objects at once with better performance.
  ///
  /// See [putAsync] for an asynchronous version.
  int put(T object, {PutMode mode = PutMode.put}) {
    if (_hasRelations) {
      return InternalStoreAccess.runInTransaction(
          _store, TxMode.write, (Transaction tx) => _put(object, mode, tx));
    } else {
      return _put(object, mode, null);
    }
  }

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static int _putAsyncCallback<T>(Store store, _PutAsyncArgs<T> args) =>
      store.box<T>().put(args.object, mode: args.mode);

  /// Like [put], but runs in a worker isolate and does not modify the given
  /// [object], e.g. to set a new ID.
  ///
  /// Use [get] to get an inserted object with its new ID set,
  /// or use [putAndGetAsync] instead.
  ///
  /// See [putManyAsync] to put several objects at once with better performance.
  ///
  /// If you need to call this multiple times consider using the synchronous
  /// variant (e.g. [put]) and wrap the calls in [Store.runInTransactionAsync].
  /// This has typically better performance as only a single worker isolate has
  /// to be spawned.
  ///
  /// See also [putQueued] which is optimized for running a large number of puts
  /// in parallel.
  Future<int> putAsync(T object, {PutMode mode = PutMode.put}) async =>
      await _store.runAsync(_putAsyncCallback<T>, _PutAsyncArgs(object, mode));

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static T _putAndGetAsyncCallback<T>(Store store, _PutAsyncArgs<T> args) {
    store.box<T>().put(args.object, mode: args.mode);
    return args.object;
  }

  /// Like [putAsync], but returns a copy of the [object] with the (new) ID set.
  ///
  /// If the object is new (its [Id] property is 0 or null), the returned copy
  /// will have its [Id] property set to the new ID. This also applies to new
  /// objects in its relations.
  ///
  /// If the object or (new) ID is not needed, use [putAsync] instead.
  ///
  /// See also [putQueued] which is optimized for running a large number of puts
  /// in parallel.
  Future<T> putAndGetAsync(T object, {PutMode mode = PutMode.put}) async =>
      await _store.runAsync(
          _putAndGetAsyncCallback<T>, _PutAsyncArgs(object, mode));

  /// Like [putQueued], but waits on the put to complete.
  ///
  /// For typical use cases, use [putAsync] instead which supports objects with
  /// relations. Use this when a large number of puts needs to be performed in
  /// parallel (e.g. this is called many times) for better performance. But then
  /// [putQueued] will achieve even better performance as it does not have to
  /// notify all callers of completion.
  ///
  /// The returned future completes with an ID of the object. If it is a new
  /// object (its ID property is 0), a new ID will be assigned to [object],
  /// after the returned [Future] completes.
  ///
  /// In extreme scenarios (e.g. having hundreds of thousands async operations
  /// per second), this may fail as internal queues fill up if the disk can't
  /// keep up. However, this should not be a concern for typical apps.
  ///
  /// The returned future may complete with an error if the put failed
  /// for another reason, for example a unique constraint violation. In that
  /// case the [object]'s id field remains unchanged (0 if it was a new object).
  ///
  /// See also [putQueued] which doesn't return a [Future] but a pre-allocated
  /// ID immediately, even though the actual database put operation may fail.
  @Deprecated(
      "Use putAsync which supports relations, or for a large number of parallel calls putQueued.")
  Future<int> putQueuedAwaitResult(T object,
          {PutMode mode = PutMode.put}) async =>
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
  /// For typical use cases, use [putAsync] instead which supports objects with
  /// relations. Use this when a large number of puts needs to be performed in
  /// parallel (e.g. this is called many times) for better performance.
  ///
  /// To wait on the completion of submitted operations, use
  /// [Store.awaitQueueSubmitted] or [Store.awaitQueueCompletion].
  ///
  /// The actual database put operation may fail even if this returned
  /// normally (and even if a new ID for a new object was returned), for example
  /// due to a unique constraint violation. So do not rely on the object being
  /// put or add checks as necessary.
  ///
  /// In extreme scenarios (e.g. having hundreds of thousands of async operations
  /// per second, not of concern for typical apps), this may fail as internal
  /// queues fill up if the disk can't keep up.
  ///
  /// See also [putAsync] which supports relations and returns a [Future] that
  /// only completes after a put was successful.
  int putQueued(T object, {PutMode mode = PutMode.put}) {
    if (_hasRelations) {
      throw UnsupportedError('putQueued() is currently not supported on entity '
          '${T.toString()} because it has relations.');
    }
    _async ??= _AsyncBoxHelper(this);

    _builder.fbb.reset();
    var id = _entity.objectToFB(object, _builder.fbb);
    final newId = C.async_put_object4(_async!._cAsync, _builder.bufPtr,
        _builder.fbb.size(), _getOBXPutMode(mode));
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
          final newId = C.box_id_for_put(_ptr, 0);
          if (newId == 0) throwLatestNativeError(context: 'id-for-put failed');
          _entity.setId(object, newId);
        }
        _putToOneRelFields(object, mode, tx);
      }
    }
    _builder.fbb.reset();
    var id = _entity.objectToFB(object, _builder.fbb);
    final newId = C.box_put_object4(
        _ptr, _builder.bufPtr, _builder.fbb.size(), _getOBXPutMode(mode));
    id = _handlePutObjectResult(object, id, newId);
    if (_hasToManyRelations) _putToManyRelFields(object, mode, tx!);
    _builder.resetIfLarge();
    return id;
  }

  /// Like [put], but optimized to put many [objects] at once.
  ///
  /// All objects are put in a single transaction (similar to using
  /// [Store.runInTransaction]), making this faster than calling [put] multiple
  /// times.
  ///
  /// Returns the IDs of all put objects.
  List<int> putMany(List<T> objects, {PutMode mode = PutMode.put}) {
    if (objects.isEmpty) return [];

    final putIds = List<int>.filled(objects.length, 0);

    InternalStoreAccess.runInTransaction(_store, TxMode.write,
        (Transaction tx) {
      if (_hasToOneRelations) {
        for (var object in objects) {
          _putToOneRelFields(object, mode, tx);
        }
      }

      final cursor = tx.cursor(_entity);
      final cMode = _getOBXPutMode(mode);
      for (var i = 0; i < objects.length; i++) {
        final object = objects[i];
        _builder.fbb.reset();
        final id = _entity.objectToFB(object, _builder.fbb);
        final newId = C.cursor_put_object4(
            cursor.ptr, _builder.bufPtr, _builder.fbb.size(), cMode);
        putIds[i] = _handlePutObjectResult(object, id, newId);
      }

      if (_hasToManyRelations) {
        for (var object in objects) {
          _putToManyRelFields(object, mode, tx);
        }
      }
      _builder.resetIfLarge();
    });

    return putIds;
  }

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static List<int> _putManyAsyncCallback<T>(
          Store store, _PutManyAsyncArgs<T> args) =>
      store.box<T>().putMany(args.objects, mode: args.mode);

  /// Like [putMany], but runs in a worker isolate and does not modify the given
  /// [objects], e.g. to set an assigned ID.
  ///
  /// Use [getMany] to get inserted objects with their assigned ID set,
  /// or use [putAndGetManyAsync] instead.
  ///
  /// If you need to call this multiple times consider using the synchronous
  /// variant (e.g. [putMany]) and wrap the calls in [Store.runInTransactionAsync].
  /// This has typically better performance as only a single worker isolate has
  /// to be spawned.
  Future<List<int>> putManyAsync(List<T> objects,
          {PutMode mode = PutMode.put}) async =>
      await _store.runAsync(
          _putManyAsyncCallback<T>, _PutManyAsyncArgs(objects, mode));

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static List<T> _putAndGetManyAsyncCallback<T>(
      Store store, _PutManyAsyncArgs<T> args) {
    store.box<T>().putMany(args.objects, mode: args.mode);
    return args.objects;
  }

  /// Like [putManyAsync], but returns a copy of the [objects] with new IDs
  /// assigned.
  ///
  /// If the objects are new (their [Id] property is 0 or null), returns a
  /// copy of them with the [Id] property set to the assigned ID. This also
  /// applies to new objects in their relations.
  Future<List<T>> putAndGetManyAsync(List<T> objects,
          {PutMode mode = PutMode.put}) async =>
      await _store.runAsync(
          _putAndGetManyAsyncCallback<T>, _PutManyAsyncArgs(objects, mode));

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

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static T? _getAsyncCallback<T>(Store store, int id) => store.box<T>().get(id);

  /// Like [get], but runs the box operation asynchronously in a worker isolate.
  ///
  /// If you need to call this multiple times consider using the synchronous
  /// variant (e.g. [get]) and wrap the calls in [Store.runInTransactionAsync].
  /// This has typically better performance as only a single worker isolate has
  /// to be spawned.
  Future<T?> getAsync(int id) => _store.runAsync(_getAsyncCallback<T>, id);

  /// Returns a list of Objects of type T, each located at the corresponding
  /// position of its ID in [ids].
  ///
  /// If an object does not exist, null is added to the list instead.
  ///
  /// Set [growableResult] to `true` for the returned list to be growable.
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

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static List<T?> _getManyAsyncCallback<T>(
          Store store, _GetManyAsyncArgs args) =>
      store.box<T>().getMany(args.ids, growableResult: args.growableResult);

  /// Like [getMany], but runs the box operation asynchronously in a worker
  /// isolate.
  ///
  /// If you need to call this multiple times consider using the synchronous
  /// variant (e.g. [getMany]) and wrap the calls in [Store.runInTransactionAsync].
  /// This has typically better performance as only a single worker isolate has
  /// to be spawned.
  Future<List<T?>> getManyAsync(List<int> ids, {bool growableResult = false}) =>
      _store.runAsync(
          _getManyAsyncCallback<T>, _GetManyAsyncArgs(ids, growableResult));

  /// Returns all stored objects in this Box.
  List<T> getAll() => InternalStoreAccess.runInTransaction(
      _store, TxMode.read, (Transaction tx) => tx.cursor(_entity).getAll());

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static List<T> _getAllAsyncCallback<T>(Store store, void param) =>
      store.box<T>().getAll();

  /// Like [getAll], but runs the box operation asynchronously in a worker
  /// isolate.
  ///
  /// If you need to call this multiple times consider using the synchronous
  /// variant (e.g. [getAll]) and wrap the calls in [Store.runInTransactionAsync].
  /// This has typically better performance as only a single worker isolate has
  /// to be spawned.
  Future<List<T>> getAllAsync() =>
      _store.runAsync(_getAllAsyncCallback<T>, null);

  /// Starts building a query which returns objects matching the supplied
  /// conditions.
  ///
  /// For example:
  /// ```
  /// final query = userBox
  ///     .query(User_.firstName.equals('Joe')
  ///         .and(User_.lastName.startsWith("O")))
  ///     .build();
  /// final joes = query.find();
  /// query.close();
  /// ```
  ///
  /// For more examples and options see https://docs.objectbox.io/queries.
  @pragma('vm:prefer-inline')
  QueryBuilder<T> query([Condition<T>? qc]) =>
      QueryBuilder<T>(_store, _entity, qc);

  /// Returns the count of all stored Objects in this box.
  /// If [limit] is not zero, stops counting at the given limit.
  int count({int limit = 0}) {
    final count = malloc<Uint64>();
    try {
      checkObx(C.box_count(_ptr, limit, count));
      return count.value;
    } finally {
      malloc.free(count);
    }
  }

  /// Returns true if no objects are in this box.
  bool isEmpty() {
    final isEmpty = malloc<Bool>();
    try {
      checkObx(C.box_is_empty(_ptr, isEmpty));
      return isEmpty.value;
    } finally {
      malloc.free(isEmpty);
    }
  }

  /// Returns true if this box contains an Object with the ID [id].
  bool contains(int id) {
    final contains = malloc<Bool>();
    try {
      checkObx(C.box_contains(_ptr, id, contains));
      return contains.value;
    } finally {
      malloc.free(contains);
    }
  }

  /// Returns true if this box contains objects with all of the given [ids].
  bool containsMany(List<int> ids) {
    final contains = malloc<Bool>();
    try {
      return executeWithIdArray(ids, (ptr) {
        checkObx(C.box_contains_many(_ptr, ptr, contains));
        return contains.value;
      });
    } finally {
      malloc.free(contains);
    }
  }

  /// Removes (deletes) the object with the given [id].
  ///
  /// If the object is part of a relation, it will be removed from that relation
  /// as well.
  ///
  /// Returns true if the object did exist and was removed, otherwise false.
  ///
  /// For an async variant see [removeAsync].
  bool remove(int id) {
    final err = C.box_remove(_ptr, id);
    if (err == OBX_NOT_FOUND) return false;
    checkObx(err); // throws on other errors
    return true;
  }

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static bool _removeAsyncCallback<T>(Store store, int id) =>
      store.box<T>().remove(id);

  /// Like [remove], but runs in a worker isolate.
  ///
  /// If you need to call this multiple times consider using the synchronous
  /// variant (e.g. [remove]) and wrap the calls in [Store.runInTransactionAsync].
  /// This has typically better performance as only a single worker isolate has
  /// to be spawned.
  Future<bool> removeAsync(int id) async =>
      await _store.runAsync(_removeAsyncCallback<T>, id);

  /// Removes (deletes) objects with the given [ids] if they exist. Returns the
  /// number of removed objects.
  int removeMany(List<int> ids) {
    final countRemoved = malloc<Uint64>();
    try {
      return executeWithIdArray(ids, (ptr) {
        checkObx(C.box_remove_many(_ptr, ptr, countRemoved));
        return countRemoved.value;
      });
    } finally {
      malloc.free(countRemoved);
    }
  }

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static int _removeManyAsyncCallback<T>(Store store, List<int> ids) =>
      store.box<T>().removeMany(ids);

  /// Like [removeMany], but runs in a worker isolate.
  ///
  /// If you need to call this multiple times consider using the synchronous
  /// variant (e.g. [removeMany]) and wrap the calls in [Store.runInTransactionAsync].
  /// This has typically better performance as only a single worker isolate has
  /// to be spawned.
  Future<int> removeManyAsync(List<int> ids) async =>
      await _store.runAsync(_removeManyAsyncCallback<T>, ids);

  /// Removes (deletes) all objects in this box. Returns the number of removed
  /// objects.
  int removeAll() {
    final removedItems = malloc<Uint64>();
    try {
      checkObx(C.box_remove_all(_ptr, removedItems));
      return removedItems.value;
    } finally {
      malloc.free(removedItems);
    }
  }

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static int _removeAllAsyncCallback<T>(Store store, void param) =>
      store.box<T>().removeAll();

  /// Like [removeAll], but runs in a worker isolate.
  ///
  /// If you need to call this multiple times consider using the synchronous
  /// variant (e.g. [removeAll]) and wrap the calls in [Store.runInTransactionAsync].
  /// This has typically better performance as only a single worker isolate has
  /// to be spawned.
  Future<int> removeAllAsync() async =>
      await _store.runAsync(_removeAllAsyncCallback<T>, null);

  void _putToOneRelFields(T object, PutMode mode, Transaction tx) {
    for (var toOne in _entity.toOneRelations(object)) {
      // To avoid all ToOnes obtaining a Store for each put,
      // pass the store of this box.
      toOne.applyToDb(_store, mode, tx);
    }
  }

  void _putToManyRelFields(T object, PutMode mode, Transaction tx) {
    _entity.toManyRelations(object).forEach((RelInfo info, ToMany rel) {
      // Always set relation info so ToMany applyToDb can be used after initial put
      InternalToManyAccess.setRelInfo<T>(rel, _store, info);
      if (InternalToManyAccess.hasPendingDbChanges(rel)) {
        // To avoid all ToManys obtaining a Store for each put,
        // pass the store of this box.
        rel.applyToDb(existingStore: _store, mode: mode, tx: tx);
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

/// Something like an "async box": keeps an OBX_async pointer and offers
/// functions to handle async messages (e.g. via ReceivePort).
class _AsyncBoxHelper {
  final Pointer<OBX_async> _cAsync;

  _AsyncBoxHelper(Box box) : _cAsync = C.async1(box._ptr) {
    initializeDartAPI();
  }

  /// Put the given buffer as an object asynchronously.
  /// Internally, this depends on the dartc_async_put_object C function,
  /// which call an obx_async_put function with a callback. The callback sends
  /// an empty message if successful, or an error string.
  Future<int> put(int id, BuilderWithCBuffer fbb, PutMode mode) async {
    final port = ReceivePort();
    final newId = C.dartc_async_put_object(_cAsync, port.sendPort.nativePort,
        fbb.bufPtr, fbb.fbb.size(), _getOBXPutMode(mode));

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
      checkObx(C.box_rel_put(box._ptr, relationId, sourceId, targetId));

  /// Remove a standalone relation entry between two objects.
  @pragma('vm:prefer-inline')
  static void relRemove(
    Box box,
    int relationId,
    int sourceId,
    int targetId,
  ) =>
      checkObx(C.box_rel_remove(box._ptr, relationId, sourceId, targetId));

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
            cIdsPtr = C.box_rel_get_ids(box._ptr, rel.id, rel.objectId);
            break;
          case RelType.toOneBacklink:
            cIdsPtr = C.box_get_backlink_ids(box._ptr, rel.id, rel.objectId);
            break;
          case RelType.toManyBacklink:
            cIdsPtr =
                C.box_rel_get_backlink_ids(box._ptr, rel.id, rel.objectId);
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
              final object = cursor.get(cIds.ids[i]);
              if (object != null) {
                result.add(object);
              }
            }
          }
        } finally {
          C.id_array_free(cIdsPtr);
        }
        return result;
      });
}

class _PutAsyncArgs<T> {
  final T object;
  final PutMode mode;

  _PutAsyncArgs(this.object, this.mode);
}

class _PutManyAsyncArgs<T> {
  final List<T> objects;
  final PutMode mode;

  _PutManyAsyncArgs(this.objects, this.mode);
}

class _GetManyAsyncArgs {
  final List<int> ids;
  final bool growableResult;

  // ignore: avoid_positional_boolean_parameters
  _GetManyAsyncArgs(this.ids, this.growableResult);
}
