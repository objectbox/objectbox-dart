import "dart:ffi";

import "store.dart";
import "bindings/bindings.dart";
import "bindings/constants.dart";
import "bindings/flatbuffers.dart";
import "bindings/helpers.dart";
import "bindings/structs.dart";

enum PutMode {
  Put,
  Insert,
  Update,
}

class Box<T> {
  Store _store;
  Pointer<Void> _objectboxBox;
  var _entityDefinition, _entityReader, _entityBuilder, _fbManager;
  var _idPropName;

  Box(this._store) {
    _entityDefinition = _store.getEntityModelDefinitionFromClass(T);
    _entityReader = _store.getEntityReaderFromClass<T>();
    _entityBuilder = _store.getEntityBuilderFromClass<T>();
    _fbManager = new OBXFlatbuffersManager<T>(_entityDefinition, _entityReader, _entityBuilder);

    for (int i = 0; i < _entityDefinition["properties"].length; ++i) {
      final p = _entityDefinition["properties"][i];
      if ((p["flags"] & OBXPropertyFlag.ID) != 0) {
        _idPropName = p["name"];
        break;
      }
    }

    if (_idPropName == null) throw Exception("entity ${_entityDefinition["name"]} has no id property");
    _objectboxBox = bindings.obx_box(_store.ptr, new IdUid(_entityDefinition["id"]).id);
    checkObxPtr(_objectboxBox, "failed to create box");
  }

  _getOBXPutMode(PutMode mode) {
    switch (mode) {
      case PutMode.Put:
        return OBXPutMode.PUT;
      case PutMode.Insert:
        return OBXPutMode.INSERT;
      case PutMode.Update:
        return OBXPutMode.UPDATE;
    }
  }

  // if the respective ID property is given as null or 0, a newly assigned ID is returned, otherwise the existing ID is returned
  int put(T inst, {PutMode mode = PutMode.Put}) {
    var propVals = _entityReader(inst);
    if (propVals[_idPropName] == null || propVals[_idPropName] == 0) {
      final id = bindings.obx_box_id_for_put(_objectboxBox, 0);
      propVals[_idPropName] = id;
    }

    // put object into box and free the buffer
    ByteBuffer buffer = _fbManager.marshal(propVals);
    checkObx(
        bindings.obx_box_put(_objectboxBox, propVals[_idPropName], buffer.voidPtr, buffer.size, _getOBXPutMode(mode)));
    buffer.free();
    return propVals[_idPropName];
  }

  // only instances whose ID property ot null or 0 will be given a new, valid number for that. A list of the final IDs is returned
  List<int> putMany(List<T> insts, {PutMode mode = PutMode.Put}) {
    if (insts.length == 0) return [];

    // read all property values and find number of instances where ID is missing
    var allPropVals = insts.map(_entityReader).toList();
    int numInstsMissingId = 0;
    for (var instPropVals in allPropVals)
      if (instPropVals[_idPropName] == null || instPropVals[_idPropName] == 0) ++numInstsMissingId;

    // generate new IDs for these instances and set them
    Pointer<Uint64> firstIdMemory;
    if (numInstsMissingId != 0) {
      firstIdMemory = Pointer<Uint64>.allocate(count: 1);
      checkObx(bindings.obx_box_ids_for_put(_objectboxBox, numInstsMissingId, firstIdMemory));
      int nextId = firstIdMemory.load<int>();
      firstIdMemory.free();
      for (var instPropVals in allPropVals)
        if (instPropVals[_idPropName] == null || instPropVals[_idPropName] == 0) instPropVals[_idPropName] = nextId++;
    }

    // because obx_box_put_many also needs a list of all IDs of the elements to be put into the box, generate this list now (only needed if not all IDs have been generated)
    Pointer<Uint64> allIdsMemory = Pointer<Uint64>.allocate(count: insts.length);
    for (int i = 0; i < allPropVals.length; ++i) allIdsMemory.elementAt(i).store(allPropVals[i][_idPropName]);

    // marshal all objects to be put into the box
    var putObjects = ByteBufferArray(allPropVals.map<ByteBuffer>(_fbManager.marshal).toList()).toOBXBytesArray();

    checkObx(bindings.obx_box_put_many(_objectboxBox, putObjects.ptr, allIdsMemory, _getOBXPutMode(mode)));
    putObjects.free();
    allIdsMemory.free();
    return allPropVals.map((p) => p[_idPropName] as int).toList();
  }

  // TODO move to Store
  T _runInTransaction<T>(bool readOnly, T Function() fn) {
    assert(readOnly); // TODO implement write transactions

    Pointer<Void> txn = bindings.obx_txn_read(_store.ptr);
    checkObxPtr(txn, "failed to created transaction");
    try {
      return fn();
    } finally {
      checkObx(bindings.obx_txn_close(txn));
    }
  }

  get(int id) {
    Pointer<Pointer<Void>> dataPtr = Pointer<Pointer<Void>>.allocate();
    Pointer<Int32> sizePtr = Pointer<Int32>.allocate();

    // get element with specified id from database
    return _runInTransaction(true, () {
      checkObx(bindings.obx_box_get(_objectboxBox, id, dataPtr, sizePtr));

      Pointer<Uint8> data = Pointer<Uint8>.fromAddress(dataPtr.load<Pointer<Void>>().address);
      var size = sizePtr.load<int>();

      // transform bytes from memory to Dart byte list
      var buffer = ByteBuffer(data, size);
      dataPtr.free();
      sizePtr.free();

      return _fbManager.unmarshal(buffer);
    });
  }

  List<T> _getMany(Pointer<Uint64> Function() cCall) {
    return _runInTransaction(true, () {
      // OBX_bytes_array*, has two Uint64 members (data and size)
      Pointer<Uint64> bytesArray = cCall();
      try {
        return _fbManager.unmarshalArray(bytesArray);
      } finally {
        bindings.obx_bytes_array_free(bytesArray);
      }
    });
  }

  // returns list of ids.length objects of type T, each corresponding to the location of its ID in the ids array. Non-existant IDs become null
  List<T> getMany(List<int> ids) {
    if (ids.length == 0) return [];

    // write ids in buffer for FFI call
    var idArray = new IDArray(ids);

    try {
      return _getMany(() => checkObxPtr(
          bindings.obx_box_get_many(_objectboxBox, idArray.ptr), "failed to get many objects from box", true));
    } finally {
      idArray.free();
    }
  }

  List<T> getAll() {
    return _getMany(
        () => checkObxPtr(bindings.obx_box_get_all(_objectboxBox), "failed to get all objects from box", true));
  }

  get ptr => _objectboxBox;
}