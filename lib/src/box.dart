import "dart:ffi";
import 'dart:typed_data';

import 'common.dart';
import "store.dart";
import "bindings/bindings.dart";
import "bindings/constants.dart";
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

class Box<T> {
  Store _store;
  Pointer<Void> _cBox;
  ModelEntity _modelEntity;
  ObjectReader<T> _entityReader;
  OBXFlatbuffersManager _fbManager;

  Box(this._store) {
    EntityDefinition<T> entityDefs = _store.entityDef<T>();
    _modelEntity = entityDefs.getModel();
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

  // if the respective ID property is given as null or 0, a newly assigned ID is returned, otherwise the existing ID is returned
  int put(T object, {_PutMode mode = _PutMode.Put}) {
    var propVals = _entityReader(object);
    if (propVals[_modelEntity.idPropName] == null || propVals[_modelEntity.idPropName] == 0) {
      final id = bindings.obx_box_id_for_put(_cBox, 0); // TODO check error if 0 was returned instead of an ID
      propVals[_modelEntity.idPropName] = id;
    }

    // put object into box and free the buffer
    final Pointer<OBX_bytes> bytesPtr = _fbManager.marshal(propVals);
    try {
      final OBX_bytes bytes = bytesPtr.load();
      checkObx(bindings.obx_box_put(
          _cBox, propVals[_modelEntity.idPropName], bytes.ptr, bytes.length, _getOBXPutMode(mode)));
    } finally {
      // because fbManager.marshal() allocates the inner bytes, we need to clean those as well
      OBX_bytes.freeManaged(bytesPtr);
    }
    return propVals[_modelEntity.idPropName];
  }

  // only instances whose ID property ot null or 0 will be given a new, valid number for that. A list of the final IDs is returned
  List<int> putMany(List<T> objects, {_PutMode mode = _PutMode.Put}) {
    if (objects.isEmpty) return [];

    // read all property values and find number of instances where ID is missing
    var allPropVals = objects.map(_entityReader).toList();
    int missingIdsCount = 0;
    for (var instPropVals in allPropVals) {
      if (instPropVals[_modelEntity.idPropName] == null || instPropVals[_modelEntity.idPropName] == 0) {
        ++missingIdsCount;
      }
    }

    // generate new IDs for these instances and set them
    if (missingIdsCount != 0) {
      int nextId = 0;
      Pointer<Uint64> nextIdPtr = Pointer<Uint64>.allocate(count: 1);
      try {
        checkObx(bindings.obx_box_ids_for_put(_cBox, missingIdsCount, nextIdPtr));
        nextId = nextIdPtr.load<int>();
      } finally {
        nextIdPtr.free();
      }
      for (var instPropVals in allPropVals) {
        if (instPropVals[_modelEntity.idPropName] == null || instPropVals[_modelEntity.idPropName] == 0) {
          instPropVals[_modelEntity.idPropName] = nextId++;
        }
      }
    }

    // because obx_box_put_many also needs a list of all IDs of the elements to be put into the box,
    // generate this list now (only needed if not all IDs have been generated)
    Pointer<Uint64> allIdsMemory = Pointer<Uint64>.allocate(count: objects.length);
    try {
      for (int i = 0; i < allPropVals.length; ++i) {
        allIdsMemory.elementAt(i).store(allPropVals[i][_modelEntity.idPropName] as int);
      }

      // marshal all objects to be put into the box
      // final bytesArrayPtr = OBX_bytes_array.createManaged(allPropVals.length);
      final bytesArrayPtr =
          checkObxPtr(bindings.obx_bytes_array(allPropVals.length), "could not create OBX_bytes_array");
      final listToFree = List<Pointer<OBX_bytes>>();
      try {
        // final OBX_bytes_array bytesArray = bytesArrayPtr.load();
        for (int i = 0; i < allPropVals.length; i++) {
          // bytesArray.setAndFree(i, _fbManager.marshal(allPropVals[i]));
          final bytesPtr = _fbManager.marshal(allPropVals[i]);
          listToFree.add(bytesPtr);
          final OBX_bytes bytes = bytesPtr.load();
          bindings.obx_bytes_array_set(bytesArrayPtr, i, bytes.ptr, bytes.length);
        }

        checkObx(bindings.obx_box_put_many(_cBox, bytesArrayPtr, allIdsMemory, _getOBXPutMode(mode)));
      } finally {
        // OBX_bytes_array.freeManaged(bytesArrayPtr, true);
        bindings.obx_bytes_array_free(bytesArrayPtr);
        listToFree.forEach(OBX_bytes.freeManaged);
      }
    } finally {
      allIdsMemory.free();
    }

    return allPropVals.map((p) => p[_modelEntity.idPropName] as int).toList();
  }

  get(int id) {
    final dataPtrPtr = Pointer<Pointer<Uint8>>.allocate();
    final sizePtr = Pointer<IntPtr>.allocate();

    try {
      // get element with specified id from database
      return _store.runInTransaction(TxMode.Read, () {
        checkObx(bindings.obx_box_get(_cBox, id, dataPtrPtr, sizePtr));

        Pointer<Uint8> dataPtr = dataPtrPtr.load();
        final size = sizePtr.load<int>();

        // create a no-copy view
        final bytes = Uint8List.view(dataPtr.asExternalTypedData(count: size).buffer);

        return _fbManager.unmarshal(bytes);
      });
    } finally {
      dataPtrPtr.free();
      sizePtr.free();
    }
  }

  List<T> _getMany(bool allowMissing, Pointer<OBX_bytes_array> Function() cCall) {
    return _store.runInTransaction(TxMode.Read, () {
      final bytesArray = cCall();
      try {
        return _fbManager.unmarshalArray(bytesArray, allowMissing: allowMissing);
      } finally {
        bindings.obx_bytes_array_free(bytesArray);
      }
    });
  }

  // returns list of ids.length objects of type T, each corresponding to the location of its ID in the ids array. Non-existant IDs become null
  List<T> getMany(List<int> ids) {
    if (ids.isEmpty) return [];

    const bool allowMissing = true; // returns null if null is encountered in the data found
    return OBX_id_array.executeWith(
        ids,
        (ptr) => _getMany(allowMissing,
            () => checkObxPtr(bindings.obx_box_get_many(_cBox, ptr), "failed to get many objects from box")));
  }

  List<T> getAll() {
    const bool allowMissing = false; // throw if null is encountered in the data found
    return _getMany(
        allowMissing, () => checkObxPtr(bindings.obx_box_get_all(_cBox), "failed to get all objects from box"));
  }

  QueryBuilder query(Condition qc) => QueryBuilder<T>(_store, _fbManager, _modelEntity.id.id, qc);

  int count({int limit = 0}) {
    Pointer<Uint64> count = Pointer<Uint64>.allocate();
    try {
      checkObx(bindings.obx_box_count(_cBox, limit, count));
      return count.load<int>();
    } finally {
      count.free();
    }
  }

  bool isEmpty() {
    Pointer<Uint8> isEmpty = Pointer<Uint8>.allocate();
    try {
      checkObx(bindings.obx_box_is_empty(_cBox, isEmpty));
      return isEmpty.load<int>() > 0 ? true : false;
    } finally {
      isEmpty.free();
    }
  }

  bool contains(int id) {
    Pointer<Uint8> contains = Pointer<Uint8>.allocate();
    try {
      checkObx(bindings.obx_box_contains(_cBox, id, contains));
      return contains.load<int>() > 0 ? true : false;
    } finally {
      contains.free();
    }
  }

  bool containsMany(List<int> ids) {
    Pointer<Uint8> contains = Pointer<Uint8>.allocate();
    try {
      return OBX_id_array.executeWith(ids, (ptr) {
        checkObx(bindings.obx_box_contains_many(_cBox, ptr, contains));
        return contains.load<int>() > 0 ? true : false;
      });
    } finally {
      contains.free();
    }
  }

  bool remove(int id) {
    final err = bindings.obx_box_remove(_cBox, id);
    if (err == OBXError.OBX_NOT_FOUND) return false;
    checkObx(err); // throws on other errors
    return true;
  }

  int removeMany(List<int> ids) {
    Pointer<Uint64> removedIds = Pointer<Uint64>.allocate();
    try {
      return OBX_id_array.executeWith(ids, (ptr) {
        checkObx(bindings.obx_box_remove_many(_cBox, ptr, removedIds));
        return removedIds.load<int>();
      });
    } finally {
      removedIds.free();
    }
  }

  int removeAll() {
    Pointer<Uint64> removedItems = Pointer<Uint64>.allocate();
    try {
      checkObx(bindings.obx_box_remove_all(_cBox, removedItems));
      return removedItems.load<int>();
    } finally {
      removedItems.free();
    }
  }

  get ptr => _cBox;
}
