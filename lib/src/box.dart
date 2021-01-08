import 'dart:ffi';
import 'package:ffi/ffi.dart' show allocate, free;

import '../flatbuffers/flat_buffers.dart' as fb;
import 'store.dart';
import 'bindings/bindings.dart';
import 'bindings/data_visitor.dart';
import 'bindings/flatbuffers.dart';
import 'bindings/helpers.dart';
import 'bindings/structs.dart';
import 'modelinfo/index.dart';
import 'query/query.dart';

enum _PutMode {
  Put,
  Insert,
  Update,
}

/// A box to store objects of a particular class.
class Box<T> {
  final Store _store;

  /*late final*/
  Pointer<OBX_box> _cBox;

  final EntityDefinition<T> _entity;

  final OBXFlatbuffersManager<T> _fbManager;

  final bool _supportsBytesArrays;

  Box(this._store)
      : _supportsBytesArrays = bindings.obx_supports_bytes_array(),
        _entity = _store.entityDef<T>(),
        _fbManager = OBXFlatbuffersManager<T>(_store) {
    _cBox = bindings.obx_box(_store.ptr, _entity.model.id.id);
    checkObxPtr(_cBox, 'failed to create box');
  }

  int _getOBXPutMode(_PutMode mode) {
    switch (mode) {
      case _PutMode.Put:
        return OBXPutMode.PUT;
      case _PutMode.Insert:
        return OBXPutMode.INSERT;
      case _PutMode.Update:
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
  int put(T object, {_PutMode mode = _PutMode.Put}) {
    int id;
    final fbb = fb.Builder(initialSize: 1024);
    try {
      id = _entity.objectToFB(object, fbb);
      final newId = bindings.obx_box_put_object4(
          _cBox, fbb.bufPtr, fbb.bufPtrSize, _getOBXPutMode(mode));
      id = _handlePutObjectResult(object, id, newId);
    } finally {
      fbb.bufPtrFree();
    }
    return id;
  }

  /// Puts the given [objects] into this Box in a single transaction.
  ///
  /// Returns a list of all IDs of the inserted Objects.
  List<int> putMany(List<T> objects, {_PutMode mode = _PutMode.Put}) {
    if (objects.isEmpty) return [];
    final putIds = <int>[];

    _store.runInTransactionWithPtr(TxMode.Write, (Pointer<OBX_txn> txn) {
      final cCursor = checkObxPtr(bindings.obx_cursor(txn, _entity.model.id.id),
          'failed to create cursor');
      try {
        final fbb = fb.Builder(initialSize: 1024);
        final cMode = _getOBXPutMode(mode);
        try {
          objects.forEach((object) {
            fbb.reset();
            final id = _entity.objectToFB(object, fbb);
            final newId = bindings.obx_cursor_put_object4(
                cCursor, fbb.bufPtr, fbb.bufPtrSize, cMode);
            putIds.add(_handlePutObjectResult(object, id, newId));
          });
        } finally {
          fbb.bufPtrFree();
        }
      } finally {
        checkObx(bindings.obx_cursor_close(cCursor));
      }
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
        final err = bindings.obx_box_get(_cBox, id, dataPtrPtr, sizePtr);
        if (err == OBX_NOT_FOUND) {
          return null;
        }
        checkObx(err);

        // ignore: omit_local_variable_types
        Pointer<Uint8> dataPtr = dataPtrPtr.value.cast<Uint8>();
        final size = sizePtr.value;
        return _fbManager.unmarshal(dataPtr, size);
      });
    } finally {
      free(dataPtrPtr);
      free(sizePtr);
    }
  }

  List<R> _getMany<R>(
      List<R> Function(Pointer<OBX_bytes_array>) unmarshalArrayFn,
      R Function(Pointer<Uint8>, int) unmarshalSingleFn,
      Pointer<OBX_bytes_array> Function() cGetArray,
      void Function(DataVisitor) cVisit) {
    return _store.runInTransaction(TxMode.Read, () {
      if (_supportsBytesArrays) {
        final bytesArray = cGetArray();
        try {
          return unmarshalArrayFn(bytesArray);
        } finally {
          bindings.obx_bytes_array_free(bytesArray);
        }
      } else {
        final results = <R>[];
        final visitor = DataVisitor((Pointer<Uint8> dataPtr, int length) {
          results.add(unmarshalSingleFn(dataPtr, length));
          return true;
        });

        try {
          cVisit(visitor);
        } finally {
          visitor.close();
        }
        return results;
      }
    });
  }

  /// Returns a list of [ids.length] Objects of type T, each corresponding to the location of its ID in [ids].
  /// Non-existent IDs become null.
  List<T /*?*/ > getMany(List<int> ids) {
    if (ids.isEmpty) return [];

    return executeWithIdArray(
        ids,
        (ptr) => _getMany(
            _fbManager.unmarshalArrayWithMissing,
            _fbManager.unmarshalWithMissing,
            () => checkObxPtr(bindings.obx_box_get_many(_cBox, ptr),
                'failed to get many objects from box'),
            (DataVisitor visitor) => checkObx(bindings.obx_box_visit_many(
                _cBox, ptr, visitor.fn, visitor.userData))));
  }

  /// Returns all stored objects in this Box.
  List<T> getAll() {
    return _getMany(
        _fbManager.unmarshalArray,
        _fbManager.unmarshal,
        () => checkObxPtr(bindings.obx_box_get_all(_cBox),
            'failed to get all objects from box'),
        (DataVisitor visitor) => checkObx(
            bindings.obx_box_visit_all(_cBox, visitor.fn, visitor.userData)));
  }

  /// Returns a builder to create queries for Object matching supplied criteria.
  QueryBuilder<T> query([Condition /*?*/ qc]) =>
      QueryBuilder<T>(_store, _fbManager, _entity.model.id.id, qc);

  /// Returns the count of all stored Objects in this box or, if [limit] is not zero, the given [limit], whichever
  /// is lower.
  int count({int limit = 0}) {
    final count = allocate<Uint64>();
    try {
      checkObx(bindings.obx_box_count(_cBox, limit, count));
      return count.value;
    } finally {
      free(count);
    }
  }

  /// Returns true if no objects are in this box.
  bool isEmpty() {
    final isEmpty = allocate<Uint8>();
    try {
      checkObx(bindings.obx_box_is_empty(_cBox, isEmpty));
      return isEmpty.value == 1;
    } finally {
      free(isEmpty);
    }
  }

  /// Returns true if this box contains an Object with the ID [id].
  bool contains(int id) {
    final contains = allocate<Uint8>();
    try {
      checkObx(bindings.obx_box_contains(_cBox, id, contains));
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
        checkObx(bindings.obx_box_contains_many(_cBox, ptr, contains));
        return contains.value == 1;
      });
    } finally {
      free(contains);
    }
  }

  /// Removes (deletes) the Object with the ID [id]. Returns true if an entity was actually removed and false if no
  /// entity exists with the given ID.
  bool remove(int id) {
    final err = bindings.obx_box_remove(_cBox, id);
    if (err == OBX_NOT_FOUND) return false;
    checkObx(err); // throws on other errors
    return true;
  }

  /// Removes (deletes) Objects by their ID in a single transaction. Returns a list of IDs of all removed Objects.
  int removeMany(List<int> ids) {
    final countRemoved = allocate<Uint64>();
    try {
      return executeWithIdArray(ids, (ptr) {
        checkObx(bindings.obx_box_remove_many(_cBox, ptr, countRemoved));
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
      checkObx(bindings.obx_box_remove_all(_cBox, removedItems));
      return removedItems.value;
    } finally {
      free(removedItems);
    }
  }

  /// The low-level pointer to this box.
  Pointer<OBX_box> get ptr => _cBox;
}
