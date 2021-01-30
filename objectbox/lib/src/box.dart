import 'dart:ffi';

import 'package:ffi/ffi.dart' show allocate, free;

import 'bindings/bindings.dart';
import 'bindings/flatbuffers.dart';
import 'bindings/helpers.dart';
import 'bindings/structs.dart';
import 'modelinfo/index.dart';
import 'query/query.dart';
import 'relations/info.dart';
import 'relations/to_many.dart';
import 'relations/to_one.dart';
import 'store.dart';
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
/// to interact with each:
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

  /// Create a box for an Entity.
  factory Box(Store store) => store.box();

  Box._(this._store, this._entity)
      : _hasToOneRelations = _entity.model.properties
            .any((ModelProperty prop) => prop.isRelation),
        _hasToManyRelations = _entity.model.relations.isNotEmpty ||
            _entity.model.backlinks.isNotEmpty,
        _cBox = C.box(_store.ptr, _entity.model.id.id) {
    checkObxPtr(_cBox, 'failed to create box');
  }

  bool get _hasRelations => _hasToOneRelations || _hasToManyRelations;

  static int _getOBXPutMode(PutMode mode) {
    switch (mode) {
      case PutMode.put:
        return OBXPutMode.PUT;
      case PutMode.insert:
        return OBXPutMode.INSERT;
      case PutMode.update:
        return OBXPutMode.UPDATE;
    }
    throw Exception('Invalid put mode ' + mode.toString());
  }

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
      final tx = Transaction(_store, TxMode.write);
      try {
        final id = _put(object, mode, tx);
        tx.markSuccessful();
        return id;
      } finally {
        tx.close();
      }
    } else {
      return _put(object, mode, null);
    }
  }

  int _put(T object, PutMode mode, Transaction /*?*/ tx) {
    if (_hasRelations) {
      if (tx == null) {
        throw Exception(
            'Invalid state: can only use _put() on an entity with relations when executing from inside a write transaction.');
      }
      if (_hasToOneRelations) _putToOneRelFields(object, mode, tx);
    }
    var id = _entity.objectToFB(object, _builder.fbb);
    final newId = C.box_put_object4(_cBox, _builder.bufPtr.cast<Void>(),
        _builder.fbb.size, _getOBXPutMode(mode));
    id = _handlePutObjectResult(object, id, newId);
    if (_hasToManyRelations) _putToManyRelFields(object, mode, tx);
    _builder.resetIfLarge();
    return id;
  }

  /// Puts the given [objects] into this Box in a single transaction.
  ///
  /// Returns a list of all IDs of the inserted Objects.
  List<int> putMany(List<T> objects, {PutMode mode = PutMode.put}) {
    if (objects.isEmpty) return [];

    final putIds = List<int>.filled(objects.length, 0);

    final tx = Transaction(_store, TxMode.write);
    try {
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
            cursor.ptr, _builder.bufPtr.cast<Void>(), _builder.fbb.size, cMode);
        putIds[i] = _handlePutObjectResult(object, id, newId);
      }

      if (_hasToManyRelations) {
        objects.forEach((object) => _putToManyRelFields(object, mode, tx));
      }
      _builder.resetIfLarge();
      tx.markSuccessful();
    } finally {
      tx.close();
    }

    return putIds;
  }

  // Checks if native obx_*_put_object() was successful (result is a valid ID).
  // Sets the given ID on the object if previous ID was zero (new object).
  int _handlePutObjectResult(T object, int prevId, int result) {
    if (result == 0) throw latestNativeError(dartMsg: 'object put failed');
    if (prevId == 0) _entity.setId(object, result);
    return result;
  }

  /// Retrieves the stored object with the ID [id] from this box's database.
  /// Returns null if an object with the given ID doesn't exist.
  T /*?*/ get(int id) {
    final tx = Transaction(_store, TxMode.read);
    try {
      return tx.cursor(_entity).get(id);
    } finally {
      tx.close();
    }
  }

  /// Returns a list of [ids.length] Objects of type T, each corresponding to
  /// the location of its ID in [ids]. Non-existent IDs become null.
  ///
  /// Pass growableResult: true for the resulting list to be growable.
  List<T /*?*/ > getMany(List<int> ids, {bool growableResult = false}) {
    final result = List<T>.filled(ids.length, null, growable: growableResult);
    if (ids.isEmpty) return result;
    final tx = Transaction(_store, TxMode.read);
    try {
      final cursor = tx.cursor(_entity);
      for (var i = 0; i < ids.length; i++) {
        final object = cursor.get(ids[i]);
        if (object != null) result[i] = object;
      }
      return result;
    } finally {
      tx.close();
    }
  }

  /// Returns all stored objects in this Box.
  List<T> getAll() {
    final tx = Transaction(_store, TxMode.read);
    try {
      final cursor = tx.cursor(_entity);
      final result = <T>[];
      var code = C.cursor_first(cursor.ptr, cursor.dataPtrPtr, cursor.sizePtr);
      while (code != OBX_NOT_FOUND) {
        checkObx(code);
        result.add(_entity.objectFromFB(_store, cursor.readData));
        code = C.cursor_next(cursor.ptr, cursor.dataPtrPtr, cursor.sizePtr);
      }
      return result;
    } finally {
      tx.close();
    }
  }

  /// Returns a builder to create queries for Object matching supplied criteria.
  QueryBuilder<T> query([Condition /*?*/ qc]) =>
      QueryBuilder<T>(_store, _entity, qc);

  /// Returns the count of all stored Objects in this box.
  /// If [limit] is not zero, stops counting at the given limit.
  int count({int limit = 0}) {
    final count = allocate<Uint64>();
    try {
      checkObx(C.box_count(_cBox, limit, count));
      return count.value;
    } finally {
      free(count);
    }
  }

  /// Returns true if no objects are in this box.
  bool isEmpty() {
    final isEmpty = allocate<Uint8>();
    try {
      checkObx(C.box_is_empty(_cBox, isEmpty));
      return isEmpty.value == 1;
    } finally {
      free(isEmpty);
    }
  }

  /// Returns true if this box contains an Object with the ID [id].
  bool contains(int id) {
    final contains = allocate<Uint8>();
    try {
      checkObx(C.box_contains(_cBox, id, contains));
      return contains.value == 1;
    } finally {
      free(contains);
    }
  }

  /// Returns true if this box contains objects with all of the given [ids].
  bool containsMany(List<int> ids) {
    final contains = allocate<Uint8>();
    try {
      return executeWithIdArray(ids, (ptr) {
        checkObx(C.box_contains_many(_cBox, ptr, contains));
        return contains.value == 1;
      });
    } finally {
      free(contains);
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
    final countRemoved = allocate<Uint64>();
    try {
      return executeWithIdArray(ids, (ptr) {
        checkObx(C.box_remove_many(_cBox, ptr, countRemoved));
        return countRemoved.value;
      });
    } finally {
      free(countRemoved);
    }
  }

  /// Removes (deletes) ALL Objects in a single transaction.
  int removeAll() {
    final removedItems = allocate<Uint64>();
    try {
      checkObx(C.box_remove_all(_cBox, removedItems));
      return removedItems.value;
    } finally {
      free(removedItems);
    }
  }

  /// The low-level pointer to this box.
  Pointer<OBX_box> get ptr => _cBox;

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

/// Internal only.
// TODO enable annotation once meta:1.3.0 is out
// @internal
class InternalBoxAccess {
  /// Create a box in the store for the given entity.
  static Box<T> create<T>(Store store, EntityDefinition<T> entity) =>
      Box._(store, entity);

  /// Close the box, freeing resources.
  static void close(Box box) => box._builder.clear();
}
