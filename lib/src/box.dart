import "dart:ffi";
import "dart:typed_data" show Uint8List;
import "package:flat_buffers/flat_buffers.dart" as fb;

import "store.dart";
import "bindings/bindings.dart";
import "bindings/constants.dart";
import "bindings/helpers.dart";
import "bindings/structs.dart";

enum PutMode {
  Put,
  Insert,
  Update,
}

class _OBXFBEntity {
  _OBXFBEntity._(this._bc, this._bcOffset);
  static const fb.Reader<_OBXFBEntity> reader = const _OBXFBEntityReader();
  factory _OBXFBEntity(Uint8List bytes) {
    fb.BufferContext rootRef = new fb.BufferContext.fromBytes(bytes);
    return reader.read(rootRef, 0);
  }

  final fb.BufferContext _bc;
  final int _bcOffset;

  getProp(propReader, int field) => propReader.vTableGet(_bc, _bcOffset, field);
}

class _OBXFBEntityReader extends fb.TableReader<_OBXFBEntity> {
  const _OBXFBEntityReader();

  @override
  _OBXFBEntity createObject(fb.BufferContext bc, int offset) => new _OBXFBEntity._(bc, offset);
}

class Box<T> {
  Store _store;
  Pointer<Void> _objectboxBox;
  var _entityDefinition, _entityReader, _entityBuilder;

  Box(this._store) {
    _entityDefinition = _store.getEntityModelDefinitionFromClass(T);
    _entityReader = _store.getEntityReaderFromClass<T>();
    _entityBuilder = _store.getEntityBuilderFromClass<T>();

    _objectboxBox = bindings.obx_box(_store.ptr, _entityDefinition["entity"]["id"]);
    checkObxPtr(_objectboxBox, "failed to create box");
  }

  ByteBuffer _marshal(propVals) {
    var builder = new fb.Builder(initialSize: 1024);

    // write all strings
    Map<String, int> offsets = {};
    _entityDefinition["properties"].forEach((p) {
      switch (p["type"]) {
        case OBXPropertyType.String:
          offsets[p["name"]] = builder.writeString(propVals[p["name"]]);
          break;
      }
    });

    // create table and write actual properties
    // TODO: make sure that Id property has a value >= 1
    builder.startTable();
    _entityDefinition["properties"].forEach((p) {
      var field = p["flatbuffers_id"], value = propVals[p["name"]];
      switch (p["type"]) {
        case OBXPropertyType.Bool:
          builder.addBool(field, value);
          break;
        case OBXPropertyType.Char:
          builder.addInt8(field, value);
          break;
        case OBXPropertyType.Byte:
          builder.addUint8(field, value);
          break;
        case OBXPropertyType.Short:
          builder.addInt16(field, value);
          break;
        case OBXPropertyType.Int:
          builder.addInt32(field, value);
          break;
        case OBXPropertyType.Long:
          builder.addInt64(field, value);
          break;
        case OBXPropertyType.String:
          builder.addOffset(field, offsets[p["name"]]);
          break;
        default:
          throw Exception("unsupported type: ${p['type']}"); // TODO: support more types
      }
    });

    var endOffset = builder.endTable();
    return ByteBuffer.allocate(builder.finish(endOffset));
  }

  T _unmarshal(ByteBuffer buffer) {
    if (buffer.size == 0 || buffer.address == 0) return null;
    Map<String, dynamic> propVals = {};
    var entity = new _OBXFBEntity(buffer.data);

    _entityDefinition["properties"].forEach((p) {
      var propReader;
      switch (p["type"]) {
        case OBXPropertyType.Bool:
          propReader = fb.BoolReader();
          break;
        case OBXPropertyType.Char:
          propReader = fb.Int8Reader();
          break;
        case OBXPropertyType.Byte:
          propReader = fb.Uint8Reader();
          break;
        case OBXPropertyType.Short:
          propReader = fb.Int16Reader();
          break;
        case OBXPropertyType.Int:
          propReader = fb.Int32Reader();
          break;
        case OBXPropertyType.Long:
          propReader = fb.Int64Reader();
          break;
        case OBXPropertyType.String:
          propReader = fb.StringReader();
          break;
        default:
          throw Exception("unsupported type: ${p['type']}"); // TODO: support more types
      }

      propVals[p["name"]] = entity.getProp(propReader, (p["flatbuffers_id"] + 2) * 2);
    });

    return _entityBuilder(propVals);
  }

  // expects pointer to OBX_bytes_array and manually resolves its contents (see objectbox.h)
  List<T> _unmarshalArray(Pointer<Uint64> bytesArray) {
    return ByteBufferArray.fromOBXBytesArray(bytesArray).buffers.map<T>((b) => _unmarshal(b)).toList();
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
    var idPropName = _entityDefinition["idPropertyName"];
    if (propVals[idPropName] == null || propVals[idPropName] == 0) {
      final id = bindings.obx_box_id_for_put(_objectboxBox, 0);
      propVals[idPropName] = id;
    }

    // put object into box and free the buffer
    ByteBuffer buffer = _marshal(propVals);
    checkObx(
        bindings.obx_box_put(_objectboxBox, propVals[idPropName], buffer.voidPtr, buffer.size, _getOBXPutMode(mode)));
    buffer.free();
    return propVals[idPropName];
  }

  // only instances whose ID property ot null or 0 will be given a new, valid number for that. A list of the final IDs is returned
  List<int> putMany(List<T> insts, {PutMode mode = PutMode.Put}) {
    if (insts.length == 0) return [];

    // read all property values and find number of instances where ID is missing
    var allPropVals = insts.map(_entityReader).toList();
    var idPropName = _entityDefinition["idPropertyName"];
    int numInstsMissingId = 0;
    for (var instPropVals in allPropVals)
      if (instPropVals[idPropName] == null || instPropVals[idPropName] == 0) ++numInstsMissingId;

    // generate new IDs for these instances and set them
    Pointer<Uint64> firstIdMemory;
    if (numInstsMissingId != 0) {
      firstIdMemory = Pointer<Uint64>.allocate(count: 1);
      checkObx(bindings.obx_box_ids_for_put(_objectboxBox, numInstsMissingId, firstIdMemory));
      int nextId = firstIdMemory.load<int>();
      firstIdMemory.free();
      for (var instPropVals in allPropVals)
        if (instPropVals[idPropName] == null || instPropVals[idPropName] == 0) instPropVals[idPropName] = nextId++;
    }

    // because obx_box_put_many also needs a list of all IDs of the elements to be put into the box, generate this list now (only needed if not all IDs have been generated)
    Pointer<Uint64> allIdsMemory = Pointer<Uint64>.allocate(count: insts.length);
    for (int i = 0; i < allPropVals.length; ++i) allIdsMemory.elementAt(i).store(allPropVals[i][idPropName]);

    // marshal all objects to be put into the box
    var putObjects = ByteBufferArray(allPropVals.map(_marshal).toList()).toOBXBytesArray();

    checkObx(bindings.obx_box_put_many(_objectboxBox, putObjects.ptr, allIdsMemory, _getOBXPutMode(mode)));
    putObjects.free();
    allIdsMemory.free();
    return allPropVals.map((p) => p[idPropName] as int).toList();
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

      return _unmarshal(buffer);
    });
  }

  List<T> _getMany(Pointer<Uint64> Function() cCall) {
    return _runInTransaction(true, () {
      // OBX_bytes_array*, has two Uint64 members (data and size)
      Pointer<Uint64> bytesArray = cCall();
      try {
        return _unmarshalArray(bytesArray);
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

  close() {
    if (_store != null) {
      _store.close();
      _store = null;
    }
  }

  get ptr => _objectboxBox;
}
