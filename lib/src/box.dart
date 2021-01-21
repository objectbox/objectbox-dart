import 'dart:ffi';

import 'package:ffi/ffi.dart' show allocate, free;

import 'store.dart';
import 'bindings/bindings.dart';
import 'bindings/flatbuffers.dart';
import 'bindings/helpers.dart';
import 'bindings/structs.dart';
import 'modelinfo/index.dart';
import 'query/query.dart';
import 'relations/info.dart';
import 'relations/to_one.dart';
import 'relations/to_many.dart';
import 'util.dart';

enum PutMode {
  Put,
  Insert,
  Update,
}

/// Global internal storage of all boxes for the given store.
final _boxes = <Store, Map<Type, Box>>{};

// we need this to clear c-allocated memory in the BuilderWithCBuffer()
void _closeStoreBoxes(Store store) {
  _boxes[store].values.map((box) => box._builder.clear());
}

/// A box to store objects of a particular class.
class Box<T> {
  final Store _store;

  /*late final*/
  Pointer<OBX_box> _cBox;

  final EntityDefinition<T> _entity;

  /*late final*/
  bool _hasToOneRelations;

  /*late final*/
  bool _hasToManyRelations;

  final _builder = BuilderWithCBuffer();

  factory Box(Store store) {
    if (!_boxes.containsKey(store)) {
      _boxes[store] = <Type, Box>{};
      final listenerKey = 'boxes';
      StoreCloseObserver.addListener(store, listenerKey, () {
        _closeStoreBoxes(store);
        StoreCloseObserver.removeListener(store, listenerKey);
      });
    }
    final storeBoxes = _boxes[store];
    if (!storeBoxes.containsKey(T)) {
      return storeBoxes[T] = Box<T>._(store);
    }
    return storeBoxes[T];
  }

  Box._(this._store) : _entity = _store.entityDef<T>() {
    _hasToOneRelations = _entity.model.properties
        .any((ModelProperty prop) => prop.type == OBXPropertyType.Relation);
    _hasToManyRelations = _entity.model.relations.isNotEmpty;
    _cBox = C.box(_store.ptr, _entity.model.id.id);
    checkObxPtr(_cBox, 'failed to create box');
  }

  bool get _hasRelations => _hasToOneRelations || _hasToManyRelations;

  static int _getOBXPutMode(PutMode mode) {
    switch (mode) {
      case PutMode.Put:
        return OBXPutMode.PUT;
      case PutMode.Insert:
        return OBXPutMode.INSERT;
      case PutMode.Update:
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
  int put(T object, {PutMode mode = PutMode.Put}) {
    if (_hasRelations) {
      return _store.runInTransaction(
          TxMode.Write, () => _put(object, mode, true));
    } else {
      return _put(object, mode, false);
    }
  }

  int _put(T object, PutMode mode, bool inTx) {
    if (_hasRelations) {
      if (!inTx) {
        throw Exception(
            'Invalid state: can only use _put() on an entity with relations when executing from inside a write transaction.');
      }
      if (_hasToOneRelations) _putToOneRelFields(object, mode);
    }
    var id = _entity.objectToFB(object, _builder.fbb);
    final newId = C.box_put_object4(_cBox, _builder.bufPtr.cast<Void>(),
        _builder.fbb.size, _getOBXPutMode(mode));
    id = _handlePutObjectResult(object, id, newId);
    if (_hasToManyRelations) _putToManyRelFields(object, mode);
    _builder.resetIfLarge();
    return id;
  }

  /// Puts the given [objects] into this Box in a single transaction.
  ///
  /// Returns a list of all IDs of the inserted Objects.
  List<int> putMany(List<T> objects, {PutMode mode = PutMode.Put}) {
    if (objects.isEmpty) return [];

    final putIds = List<int>.filled(objects.length, 0);

    _store.runInTransactionWithPtr(TxMode.Write, (Pointer<OBX_txn> txn) {
      if (_hasToOneRelations) {
        objects.forEach((object) => _putToOneRelFields(object, mode));
      }

      final cursor = CursorHelper(txn, _entity, true);
      try {
        final cMode = _getOBXPutMode(mode);
        for (var i = 0; i < objects.length; i++) {
          final object = objects[i];
          _builder.fbb.reset();
          final id = _entity.objectToFB(object, _builder.fbb);
          final newId = C.cursor_put_object4(cursor.ptr,
              _builder.bufPtr.cast<Void>(), _builder.fbb.size, cMode);
          putIds[i] = _handlePutObjectResult(object, id, newId);
        }
      } finally {
        cursor.close();
      }

      if (_hasToManyRelations) {
        objects.forEach((object) => _putToManyRelFields(object, mode));
      }
      _builder.resetIfLarge();
    });

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
    final dataPtrPtr = allocate<Pointer<Void>>();
    final sizePtr = allocate<IntPtr>();

    try {
      // get element with specified id from database
      return _store.runInTransaction(TxMode.Read, () {
        final err = C.box_get(_cBox, id, dataPtrPtr, sizePtr);
        if (err == OBX_NOT_FOUND) {
          return null;
        }
        checkObx(err);

        // ignore: omit_local_variable_types
        Pointer<Uint8> dataPtr = dataPtrPtr.value.cast<Uint8>();
        return _entity.objectFromFB(_store, dataPtr.asTypedList(sizePtr.value));
      });
    } finally {
      free(dataPtrPtr);
      free(sizePtr);
    }
  }

  /// Returns a list of [ids.length] Objects of type T, each corresponding to
  /// the location of its ID in [ids]. Non-existent IDs become null.
  ///
  /// Pass growableResult: true for the resulting list to be growable.
  List<T /*?*/ > getMany(List<int> ids, {growableResult = false}) {
    final result = List<T>.filled(ids.length, null, growable: growableResult);
    if (ids.isEmpty) return result;
    return _store.runInTransactionWithPtr(TxMode.Read, (Pointer<OBX_txn> txn) {
      final cursor = CursorHelper(txn, _entity, false);
      try {
        for (var i = 0; i < ids.length; i++) {
          final code = C.cursor_get(
              cursor.ptr, ids[i], cursor.dataPtrPtr, cursor.sizePtr);
          if (code != OBX_NOT_FOUND) {
            checkObx(code);
            result[i] = _entity.objectFromFB(_store, cursor.readData);
          }
        }
        return result;
      } finally {
        cursor.close();
      }
    });
  }

  /// Returns all stored objects in this Box.
  List<T> getAll() {
    return _store.runInTransactionWithPtr(TxMode.Read, (Pointer<OBX_txn> txn) {
      final cursor = CursorHelper(txn, _entity, false);
      try {
        final result = <T>[];
        var code =
            C.cursor_first(cursor.ptr, cursor.dataPtrPtr, cursor.sizePtr);
        while (code != OBX_NOT_FOUND) {
          checkObx(code);
          result.add(_entity.objectFromFB(_store, cursor.readData));
          code = C.cursor_next(cursor.ptr, cursor.dataPtrPtr, cursor.sizePtr);
        }
        return result;
      } finally {
        cursor.close();
      }
    });
  }

  /// Returns a builder to create queries for Object matching supplied criteria.
  QueryBuilder<T> query([Condition /*?*/ qc]) =>
      QueryBuilder<T>(_store, _entity, qc);

  /// Returns the count of all stored Objects in this box or, if [limit] is not zero, the given [limit], whichever
  /// is lower.
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

  /// Returns true if this box contains objects with all of the given [ids] using a single transaction.
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

  /// Removes (deletes) the Object with the ID [id]. Returns true if an entity was actually removed and false if no
  /// entity exists with the given ID.
  bool remove(int id) {
    final err = C.box_remove(_cBox, id);
    if (err == OBX_NOT_FOUND) return false;
    checkObx(err); // throws on other errors
    return true;
  }

  /// Removes (deletes) Objects by their ID in a single transaction. Returns a list of IDs of all removed Objects.
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

  void _putToOneRelFields(T object, PutMode mode) {
    _entity.toOneRelations(object).forEach((ToOne rel) {
      if (!rel.hasValue) return;
      rel.attach(_store);
      // put new objects
      if (rel.targetId == 0) {
        rel.targetId = rel.internalTargetBox._put(rel.target, mode, true);
      }
    });
  }

  void _putToManyRelFields(T object, PutMode mode) {
    _entity.toManyRelations(object).forEach((RelInfo info, ToMany rel) {
      rel.internalSetRelInfo(_store, info, this);
      rel.applyToDb(mode: mode);
    });
  }
}
