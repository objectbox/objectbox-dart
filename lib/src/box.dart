import "dart:ffi";
import "package:ffi/ffi.dart" show allocate, free;

import 'common.dart';
import "store.dart";
import "bindings/bindings.dart";
import "bindings/constants.dart";
import "bindings/data_visitor.dart";
import "bindings/flatbuffers.dart";
import "bindings/helpers.dart";
import "bindings/structs.dart";
import "modelinfo/index.dart";
import "query/query.dart";

enum _PutMode {
  Put,
  Insert,
  Update,
}

/// A box to store objects of a particular class.
class Box<T> {
  Store _store;
  Pointer<Void> _cBox;
  ModelEntity _modelEntity;
  ObjectReader<T> _entityReader;
  OBXFlatbuffersManager<T> _fbManager;
  final bool _supportsBytesArrays;

  Box(this._store) : _supportsBytesArrays = bindings.obx_supports_bytes_array() == 1 {
    EntityDefinition<T> entityDefs = _store.entityDef<T>();
    _modelEntity = entityDefs.model;
    _entityReader = entityDefs.reader;
    _fbManager = OBXFlatbuffersManager<T>(_modelEntity, entityDefs.writer);

    _cBox = bindings.obx_box(_store.ptr, _modelEntity.id.id);
    checkObxPtr(_cBox, "failed to create box");
  }

  _getOBXPutMode(_PutMode mode) {
    switch (mode) {
      case _PutMode.Put:
        return OBXPutMode.PUT;
      case _PutMode.Insert:
        return OBXPutMode.INSERT;
      case _PutMode.Update:
        return OBXPutMode.UPDATE;
    }
  }

  /// Puts the given Object in the box (aka persisting it). If this is a new entity (its ID property is 0), a new ID
  /// will be assigned to the entity (and returned). If the entity was already put in the box before, it will be
  /// overwritten.
  ///
  /// Performance note: if you want to put several entities, consider [putMany] instead.
  int put(T object, {_PutMode mode = _PutMode.Put}) {
    var propVals = _entityReader(object);

    int id = propVals[_modelEntity.idProperty.name];
    if (id == null || id == 0) {
      id = bindings.obx_box_id_for_put(_cBox, 0);
      if (id == 0) throw latestNativeError();
      propVals[_modelEntity.idProperty.name] = id;
    }

    // put object into box and free the buffer
    final Pointer<OBX_bytes> bytesPtr = _fbManager.marshal(propVals);
    try {
      final OBX_bytes bytes = bytesPtr.ref;
      checkObx(bindings.obx_box_put(_cBox, id, bytes.ptr, bytes.length, _getOBXPutMode(mode)));
    } finally {
      // because fbManager.marshal() allocates the inner bytes, we need to clean those as well
      OBX_bytes.freeManaged(bytesPtr);
    }
    return id;
  }

  /// Puts the given [objects] into this Box in a single transaction. Returns a list of all IDs of the inserted
  /// Objects.
  List<int> putMany(List<T> objects, {_PutMode mode = _PutMode.Put}) {
    if (objects.isEmpty) return [];

    // read all property values and find number of instances where ID is missing
    var allPropVals = objects.map(_entityReader).toList();
    int missingIdsCount = 0;
    for (var instPropVals in allPropVals) {
      if (instPropVals[_modelEntity.idProperty.name] == null || instPropVals[_modelEntity.idProperty.name] == 0) {
        ++missingIdsCount;
      }
    }

    // generate new IDs for these instances and set them
    if (missingIdsCount != 0) {
      int nextId = 0;
      Pointer<Uint64> nextIdPtr = allocate<Uint64>(count: 1);
      try {
        checkObx(bindings.obx_box_ids_for_put(_cBox, missingIdsCount, nextIdPtr));
        nextId = nextIdPtr.value;
      } finally {
        free(nextIdPtr);
      }
      for (var instPropVals in allPropVals) {
        if (instPropVals[_modelEntity.idProperty.name] == null || instPropVals[_modelEntity.idProperty.name] == 0) {
          instPropVals[_modelEntity.idProperty.name] = nextId++;
        }
      }
    }

    // because obx_box_put_many also needs a list of all IDs of the elements to be put into the box,
    // generate this list now (only needed if not all IDs have been generated)
    Pointer<Uint64> allIdsMemory = allocate<Uint64>(count: objects.length);
    try {
      for (int i = 0; i < allPropVals.length; ++i) {
        allIdsMemory[i] = (allPropVals[i][_modelEntity.idProperty.name] as int);
      }

      // marshal all objects to be put into the box
      final bytesArrayPtr =
          checkObxPtr(bindings.obx_bytes_array(allPropVals.length), "could not create OBX_bytes_array");
      final listToFree = List<Pointer<OBX_bytes>>();
      try {
        for (int i = 0; i < allPropVals.length; i++) {
          final bytesPtr = _fbManager.marshal(allPropVals[i]);
          listToFree.add(bytesPtr);
          final OBX_bytes bytes = bytesPtr.ref;
          bindings.obx_bytes_array_set(bytesArrayPtr, i, bytes.ptr, bytes.length);
        }

        checkObx(bindings.obx_box_put_many(_cBox, bytesArrayPtr, allIdsMemory, _getOBXPutMode(mode)));
      } finally {
        bindings.obx_bytes_array_free(bytesArrayPtr);
        listToFree.forEach(OBX_bytes.freeManaged);
      }
    } finally {
      free(allIdsMemory);
    }

    return allPropVals.map((p) => p[_modelEntity.idProperty.name] as int).toList();
  }

  /// Retrieves the stored object with the ID [id] from this box's database. Returns null if not found.
  T get(int id) {
    final dataPtrPtr = allocate<Pointer<Uint8>>();
    final sizePtr = allocate<IntPtr>();

    try {
      // get element with specified id from database
      return _store.runInTransaction(TxMode.Read, () {
        checkObx(bindings.obx_box_get(_cBox, id, dataPtrPtr, sizePtr));

        Pointer<Uint8> dataPtr = dataPtrPtr.value;
        final size = sizePtr.value;

        // create a no-copy view
        final bytes = dataPtr.asTypedList(size);

        return _fbManager.unmarshal(bytes);
      });
    } finally {
      free(dataPtrPtr);
      free(sizePtr);
    }
  }

  List<T> _getMany(
      bool allowMissing, Pointer<OBX_bytes_array> Function() cGetArray, void Function(DataVisitor) cVisit) {
    return _store.runInTransaction(TxMode.Read, () {
      if (_supportsBytesArrays) {
        final bytesArray = cGetArray();
        try {
          return _fbManager.unmarshalArray(bytesArray, allowMissing: allowMissing);
        } finally {
          bindings.obx_bytes_array_free(bytesArray);
        }
      } else {
        final results = <T>[];
        final visitor = DataVisitor((Pointer<Uint8> dataPtr, int length) {
          if (dataPtr == null || dataPtr.address == 0 || length == 0) {
            if (allowMissing) {
              results.add(null);
              return true;
            } else {
              throw Exception('Object not found');
            }
          }
          final bytes = dataPtr.asTypedList(length);
          results.add(_fbManager.unmarshal(bytes));
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
  List<T> getMany(List<int> ids) {
    if (ids.isEmpty) return [];

    const bool allowMissing = true; // result includes null if an object is missing
    return OBX_id_array.executeWith(
        ids,
        (ptr) => _getMany(
            allowMissing,
            () => checkObxPtr(bindings.obx_box_get_many(_cBox, ptr), "failed to get many objects from box"),
            (DataVisitor visitor) => checkObx(bindings.obx_box_visit_many(_cBox, ptr, visitor.fn, visitor.userData))));
  }

  /// Returns all stored objects in this Box.
  List<T> getAll() {
    const bool allowMissing = false; // throw if null is encountered in the data found
    return _getMany(
        allowMissing,
        () => checkObxPtr(bindings.obx_box_get_all(_cBox), "failed to get all objects from box"),
        (DataVisitor visitor) => checkObx(bindings.obx_box_visit_all(_cBox, visitor.fn, visitor.userData)));
  }

  /// Returns a builder to create queries for Object matching supplied criteria.
  QueryBuilder query(Condition qc) => QueryBuilder<T>(_store, _fbManager, _modelEntity.id.id, qc);

  /// Returns the count of all stored Objects in this box or, if [limit] is not zero, the given [limit], whichever
  /// is lower.
  int count({int limit = 0}) {
    Pointer<Uint64> count = allocate<Uint64>();
    try {
      checkObx(bindings.obx_box_count(_cBox, limit, count));
      return count.value;
    } finally {
      free(count);
    }
  }

  /// Returns true if no objects are in this box.
  bool isEmpty() {
    Pointer<Uint8> isEmpty = allocate<Uint8>();
    try {
      checkObx(bindings.obx_box_is_empty(_cBox, isEmpty));
      return isEmpty.value > 0 ? true : false;
    } finally {
      free(isEmpty);
    }
  }

  /// Returns true if this box contains an Object with the ID [id].
  bool contains(int id) {
    Pointer<Uint8> contains = allocate<Uint8>();
    try {
      checkObx(bindings.obx_box_contains(_cBox, id, contains));
      return contains.value > 0 ? true : false;
    } finally {
      free(contains);
    }
  }

  /// Returns true if this box contains objects with all of the given [ids] using a single transaction.
  bool containsMany(List<int> ids) {
    Pointer<Uint8> contains = allocate<Uint8>();
    try {
      return OBX_id_array.executeWith(ids, (ptr) {
        checkObx(bindings.obx_box_contains_many(_cBox, ptr, contains));
        return contains.value > 0 ? true : false;
      });
    } finally {
      free(contains);
    }
  }

  /// Removes (deletes) the Object with the ID [id]. Returns true if an entity was actually removed and false if no
  /// entity exists with the given ID.
  bool remove(int id) {
    final err = bindings.obx_box_remove(_cBox, id);
    if (err == OBXError.OBX_NOT_FOUND) return false;
    checkObx(err); // throws on other errors
    return true;
  }

  /// Removes (deletes) Objects by their ID in a single transaction. Returns a list of IDs of all removed Objects.
  int removeMany(List<int> ids) {
    Pointer<Uint64> removedIds = allocate<Uint64>();
    try {
      return OBX_id_array.executeWith(ids, (ptr) {
        checkObx(bindings.obx_box_remove_many(_cBox, ptr, removedIds));
        return removedIds.value;
      });
    } finally {
      free(removedIds);
    }
  }

  /// Removes (deletes) ALL Objects in a single transaction.
  int removeAll() {
    Pointer<Uint64> removedItems = allocate<Uint64>();
    try {
      checkObx(bindings.obx_box_remove_all(_cBox, removedItems));
      return removedItems.value;
    } finally {
      free(removedItems);
    }
  }

  /// The low-level pointer to this box.
  get ptr => _cBox;
}
